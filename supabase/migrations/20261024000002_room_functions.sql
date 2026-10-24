-- 방·인증 처리 함수. 일반 호출은 now()를, 관리자 SQL 테스트는 _at 버전에 시험 시각을 넘긴다.

-- 현재 책상 요소 수 T = 3×A + L
create or replace function public.room_targets(r uuid)
returns table (active_count int, total_elements int, goal int, earned int)
language sql stable security definer set search_path = public as $$
  select a.cnt, 3 * a.cnt + rm.left_earned, rm.goal, rm.earned
  from rooms rm,
       lateral (select count(*)::int cnt from room_members m
                where m.room_id = rm.id and m.status = 'joined') a
  where rm.id = r
$$;

-- 사용자당 모집·예약·진행 방 합계 1개
create or replace function public._has_open_room(u uuid)
returns boolean language sql stable as $$
  select exists (select 1 from room_members m join rooms r on r.id = m.room_id
                 where m.user_id = u and m.status = 'joined'
                   and r.status in ('recruiting', 'scheduled', 'active'))
$$;

create or replace function public._next_nickname_no(r uuid, nick text)
returns int language sql stable as $$
  select coalesce(max(nickname_no), 0) + 1 from room_members where room_id = r and nickname = nick
$$;

create or replace function public.create_room(nick text)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  new_room rooms;
begin
  if u is null then raise exception 'not_authenticated'; end if;
  if _has_open_room(u) then raise exception 'already_in_room'; end if;
  insert into rooms (host_id) values (u) returning * into new_room;
  insert into room_members (room_id, user_id, nickname) values (new_room.id, u, nick);
  return new_room;
end $$;

create or replace function public._join_room_at(code text, nick text, u uuid, at timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
begin
  select * into rm from rooms where invite_code = upper(code) for update;
  if not found then raise exception 'invite_not_found'; end if;
  if rm.status <> 'recruiting' or at > rm.recruit_expires_at then raise exception 'invite_closed'; end if;
  if (select count(*) from room_members where room_id = rm.id and status = 'joined') >= 4 then
    raise exception 'room_full';
  end if;
  if _has_open_room(u) then raise exception 'already_in_room'; end if;
  insert into room_members (room_id, user_id, nickname, nickname_no)
  values (rm.id, u, nick, _next_nickname_no(rm.id, nick));
  return rm.id;
end $$;

create or replace function public.join_room(code text, nick text)
returns uuid language sql security definer set search_path = public as $$
  select public._join_room_at(code, nick, auth.uid(), now())
$$;

-- 방장 시작 확정: 다음 날 00:00 KST 시작, 3일 뒤 00:00 종료. G = 2×N0
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
  update rooms set status = 'scheduled', starts_at = start_ts, ends_at = start_ts + interval '3 days',
                   n0 = n, goal = 2 * n
  where id = r returning * into rm;
  return rm;
end $$;

create or replace function public.confirm_start(r uuid)
returns public.rooms language sql security definer set search_path = public as $$
  select public._confirm_start_at(r, auth.uid(), now())
$$;

-- 인증 저장: 새 날짜 슬롯의 첫 인증이 보상 1개(H+1). 같은 날 복구는 기존 보상 사용
create or replace function public._submit_checkin_at(r uuid, u uuid, ticket uuid, note text, at timestamptz)
returns public.checkin_slots language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  t upload_tickets;
  s checkin_slots;
  a int;
begin
  select * into rm from rooms where id = r for update;
  if rm.status = 'scheduled' and at >= rm.starts_at then
    update rooms set status = 'active' where id = r returning * into rm;
  end if;
  if rm.status <> 'active' or at >= rm.ends_at then raise exception 'room_not_active'; end if;
  if not exists (select 1 from room_members where room_id = r and user_id = u and status = 'joined') then
    raise exception 'not_member';
  end if;

  select * into t from upload_tickets where id = ticket and user_id = u and room_id = r;
  if not found or t.used then raise exception 'invalid_ticket'; end if;
  -- 자정 경계: 업로드를 시작한 날짜에 고정, 날짜가 바뀌면 저장 실패
  if t.slot_date <> kst_date(at) or at > t.expires_at then raise exception 'date_changed'; end if;
  update upload_tickets set used = true where id = ticket;

  insert into checkin_slots as cs (room_id, user_id, slot_date, photo_path, memo, checked_at)
  values (r, u, t.slot_date, t.path, note, at)
  on conflict (room_id, user_id, slot_date) do update
    set valid = true, photo_path = excluded.photo_path, memo = excluded.memo, checked_at = excluded.checked_at
    where not cs.valid
  returning * into s;
  if s is null then raise exception 'already_checked_in'; end if;

  if not s.rewarded then
    update checkin_slots set rewarded = true
    where room_id = r and user_id = u and slot_date = s.slot_date returning * into s;
    update rooms set earned = earned + 1 where id = r returning * into rm;
    select count(*) into a from room_members where room_id = r and status = 'joined';
    if rm.goal_reached_at is null and a >= 1 and rm.earned >= rm.goal then
      update rooms set goal_reached_at = at where id = r;
    end if;
  end if;
  return s;
end $$;

create or replace function public.submit_checkin(r uuid, ticket uuid, note text)
returns public.checkin_slots language sql security definer set search_path = public as $$
  select public._submit_checkin_at(r, auth.uid(), ticket, note, now())
$$;

-- 업로드 경로 발급: 하루 최대 3회, 만료는 5분 뒤와 당일 자정 중 빠른 시각
create or replace function public._issue_upload_at(r uuid, u uuid, at timestamptz)
returns public.upload_tickets language plpgsql security definer set search_path = public as $$
declare
  d date := kst_date(at);
  midnight timestamptz := ((d + 1)::timestamp at time zone 'Asia/Seoul');
  t upload_tickets;
begin
  if not exists (select 1 from room_members where room_id = r and user_id = u and status = 'joined') then
    raise exception 'not_member';
  end if;
  if (select count(*) from upload_tickets where room_id = r and user_id = u and slot_date = d) >= 3 then
    raise exception 'upload_limit';
  end if;
  insert into upload_tickets (room_id, user_id, slot_date, path, expires_at)
  values (r, u, d, r || '/' || u || '/' || d || '/' || gen_random_uuid() || '.jpg',
          least(at + interval '5 minutes', midnight))
  returning * into t;
  return t;
end $$;

create or replace function public.issue_upload(r uuid)
returns public.upload_tickets language sql security definer set search_path = public as $$
  select public._issue_upload_at(r, auth.uid(), now())
$$;

-- 인증 취소: 완료 체크 무효, 사진·메모 제거. C 감소, 획득 보상 H 유지
create or replace function public.cancel_checkin(r uuid, d date)
returns void language plpgsql security definer set search_path = public as $$
begin
  update checkin_slots set valid = false, photo_path = null, memo = null
  where room_id = r and user_id = auth.uid() and slot_date = d;
end $$;

-- 이탈: 시작 전이면 방 취소, 진행 중이면 기여 유지·미획득 몫 제외, G = min(G, 2×A + L)
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
                   goal = least(goal, 2 * a + left_earned + mine),
                   status = case when a = 0 then 'finished'::room_status else status end
  where id = r;
end $$;

create or replace function public.leave_room(r uuid)
returns void language sql security definer set search_path = public as $$
  select public._leave_room_at(r, auth.uid(), now())
$$;

-- 내부 시험 시각 함수는 일반 앱에서 호출 불가
revoke execute on function public._join_room_at, public._confirm_start_at, public._submit_checkin_at,
  public._issue_upload_at, public._leave_room_at from public, anon, authenticated;
