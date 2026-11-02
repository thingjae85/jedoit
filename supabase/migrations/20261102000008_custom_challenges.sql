-- 8단계: 챌린지 커스텀 — 방마다 할 일(종류·이름)과 기간(3·5·7일)을 정한다.
-- 기존 방은 '책상 한 구역 정리' 3일 챌린지로 그대로 동작한다.

alter table public.rooms
  add column if not exists category text not null default 'tidy'
    check (category in ('tidy', 'reading', 'study', 'exercise', 'custom')),
  add column if not exists title text not null default '책상 한 구역 정리'
    check (char_length(title) between 2 and 20),
  add column if not exists days int not null default 3
    check (days in (3, 5, 7));

-- 1인당 목표: 기간의 2/3 (3일 → 2회, 5일 → 4회, 7일 → 5회)
create or replace function public._goal_per_person(d int)
returns int language sql immutable as $$
  select ceil(d * 2 / 3.0)::int
$$;

-- 현재 진행도 칸 수 T = 기간×A + L
create or replace function public.room_targets(r uuid)
returns table (active_count int, total_elements int, goal int, earned int)
language sql stable security definer set search_path = public as $$
  select a.cnt, rm.days * a.cnt + rm.left_earned, rm.goal, rm.earned
  from rooms rm,
       lateral (select count(*)::int cnt from room_members m
                where m.room_id = rm.id and m.status = 'joined') a
  where rm.id = r
$$;

-- 방장 시작 확정: 다음 날 00:00 KST 시작, 기간만큼 진행. G = 1인당 목표 × N0
create or replace function public._confirm_start_at(r uuid, u uuid, at timestamptz)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  n int;
  start_ts timestamptz := ((kst_date(at) + 1)::timestamp at time zone 'Asia/Seoul');
begin
  select * into rm from rooms where id = r for update;
  if rm.host_id <> u then raise exception 'not_host'; end if;
  if rm.status <> 'recruiting' or at > rm.recruit_expires_at then raise exception 'not_recruiting'; end if;
  select count(*) into n from room_members where room_id = r and status = 'joined';
  if n < 2 then raise exception 'need_two_members'; end if;
  update rooms set status = 'scheduled', starts_at = start_ts, ends_at = start_ts + make_interval(days => rm.days),
                   n0 = n, goal = _goal_per_person(rm.days) * n
  where id = r returning * into rm;
  return rm;
end $$;

-- 진행 중 이탈: 목표를 남은 인원 기준으로 낮춘다 (이미 쌓인 진행도는 유지)
create or replace function public._leave_room_at(r uuid, u uuid, at timestamptz)
returns void language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  mine int;
  a int;
begin
  select * into rm from rooms where id = r for update;
  if rm.status in ('recruiting', 'scheduled') then
    if rm.status = 'scheduled' or rm.host_id = u then
      update rooms set status = 'cancelled' where id = r;
      update room_members set status = 'left', left_at = at where room_id = r and status = 'joined';
    else
      delete from room_members where room_id = r and user_id = u;
    end if;
    return;
  end if;
  if rm.status <> 'active' then return; end if;

  select count(*) into mine from checkin_slots where room_id = r and user_id = u and rewarded;
  update room_members set status = 'left', left_at = at where room_id = r and user_id = u and status = 'joined';
  select count(*) into a from room_members where room_id = r and status = 'joined';
  update rooms set left_earned = left_earned + mine,
                   goal = least(goal, _goal_per_person(days) * a + left_earned + mine),
                   status = case when a = 0 then 'finished'::room_status else status end
  where id = r;
end $$;

-- 방 만들기: 인증 방식 + 챌린지 종류·이름·기간
drop function if exists public.create_room(text, text);
create function public.create_room(
  nick text, mode text default 'result',
  category text default 'tidy', title text default '책상 한 구역 정리', days int default 3)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  new_room rooms;
  t text := btrim(title);
begin
  if u is null then raise exception 'not_authenticated'; end if;
  if mode not in ('result', 'before_after', 'light') then raise exception 'bad_mode'; end if;
  if category not in ('tidy', 'reading', 'study', 'exercise', 'custom') then raise exception 'bad_category'; end if;
  if t is null or char_length(t) not between 2 and 20 then raise exception 'bad_title'; end if;
  if days not in (3, 5, 7) then raise exception 'bad_days'; end if;
  if _has_open_room(u) then raise exception 'already_in_room'; end if;
  insert into rooms (host_id, checkin_mode, category, title, days)
  values (u, mode, category, t, days) returning * into new_room;
  insert into room_members (room_id, user_id, nickname) values (new_room.id, u, nick);
  return new_room;
end $$;

-- 방 요약에 챌린지 정보 추가
drop function if exists public.room_summary(uuid);
create function public.room_summary(r uuid)
returns table (
  id uuid, status public.room_status, invite_code text, is_host boolean,
  recruit_expires_at timestamptz, starts_at timestamptz, ends_at timestamptz,
  n0 int, active_count int, total_elements int, goal int, earned int, valid_count int,
  goal_reached_at timestamptz, checkin_mode text, category text, title text, days int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select rm.id, rm.status, rm.invite_code, rm.host_id = auth.uid(),
         rm.recruit_expires_at, rm.starts_at, rm.ends_at,
         rm.n0, t.active_count, t.total_elements, rm.goal, rm.earned,
         (select count(*)::int from checkin_slots c where c.room_id = rm.id and c.valid),
         rm.goal_reached_at, rm.checkin_mode, rm.category, rm.title, rm.days
  from rooms rm, room_targets(r) t
  where rm.id = r;
end $$;

-- 초대 미리보기: 무슨 챌린지인지도 보여 준다 (닉네임·계정 정보는 여전히 없음)
drop function if exists public.invite_preview(text);
create function public.invite_preview(code text)
returns table (room_id uuid, status public.room_status, member_count int, recruit_expires_at timestamptz,
               category text, title text, days int)
language sql stable security definer set search_path = public as $$
  select r.id, r.status,
         (select count(*)::int from room_members m where m.room_id = r.id and m.status = 'joined'),
         r.recruit_expires_at, r.category, r.title, r.days
  from rooms r where r.invite_code = upper(code)
$$;

revoke execute on function public._confirm_start_at, public._leave_room_at from public, anon, authenticated;
