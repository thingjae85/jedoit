-- 17단계: 방 설정 "바로 찍은 것만 받기"
-- 방장이 방을 만들 때 켜면, 휴대폰에서는 앨범 고르기 없이 카메라로 바로 찍은 사진·영상만 올릴 수 있다.
-- 컴퓨터에서는 카메라를 쓸 수 없으므로 앱이 지금처럼 앨범 고르기를 둔다 (서버는 파일 출처를 확인하지 않는다).

alter table public.rooms add column if not exists capture_only boolean not null default false;

-- 방 만들기: capture_only 인자를 더한다. 이전 버전은 지워서 이름 인자 호출이 헷갈리지 않게 한다.
drop function if exists public.create_room(text, text, text, text, int);
create or replace function public.create_room(nick text, mode text default 'result',
  category text default 'tidy', title text default '책상 한 구역 정리', days int default 3,
  capture_only boolean default false)
returns rooms language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  new_room rooms;
  t text := btrim(title);
begin
  if u is null then raise exception 'not_authenticated'; end if;
  if mode not in ('result', 'before_after', 'light') then raise exception 'bad_mode'; end if;
  if category not in ('tidy', 'reading', 'study', 'exercise', 'custom') then raise exception 'bad_category'; end if;
  if t is null or char_length(t) not between 2 and 20 then raise exception 'bad_title'; end if;
  if days is null or days not between 1 and 60 then raise exception 'bad_days'; end if;
  if _has_open_room(u) then raise exception 'already_in_room'; end if;
  insert into rooms (host_id, checkin_mode, category, title, days, capture_only)
  values (u, mode, category, t, days, coalesce(capture_only, false)) returning * into new_room;
  insert into room_members (room_id, user_id, nickname) values (new_room.id, u, nick);
  return new_room;
end $$;

-- 방 요약에 capture_only 추가
drop function if exists public.room_summary(uuid);
create function public.room_summary(r uuid)
returns table (
  id uuid, status public.room_status, invite_code text, is_host boolean,
  recruit_expires_at timestamptz, starts_at timestamptz, ends_at timestamptz,
  n0 int, active_count int, total_elements int, goal int, earned int, valid_count int,
  goal_reached_at timestamptz, checkin_mode text, category text, title text, days int,
  capture_only boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select rm.id, rm.status, rm.invite_code, rm.host_id = auth.uid(),
         rm.recruit_expires_at, rm.starts_at, rm.ends_at,
         rm.n0, t.active_count, t.total_elements, rm.goal, rm.earned,
         (select count(*)::int from checkin_slots c where c.room_id = rm.id and c.valid),
         rm.goal_reached_at, rm.checkin_mode, rm.category, rm.title, rm.days, rm.capture_only
  from rooms rm, room_targets(r) t
  where rm.id = r;
end $$;
