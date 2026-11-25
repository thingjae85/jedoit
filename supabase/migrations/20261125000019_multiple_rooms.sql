-- 한 계정이 여러 챌린지 방에 동시에 참여할 수 있게 한다.
-- 지금까지는 열린 방(모집·예약·진행 중)이 하나라도 있으면 방 만들기·참가를 막았다.
-- 이제는 열린 방이 kMaxOpenRooms(5)개에 이르렀을 때만 막는다.
-- create_room / _join_room_at은 그대로 _has_open_room()을 부르므로 함수 본문은 건드리지 않는다.
-- (오류 코드도 예전 앱과 맞도록 'already_in_room'을 그대로 쓴다.)

-- 이름은 그대로 두고 뜻만 "더 들어갈 수 없을 만큼 열린 방이 있다"로 바꾼다.
create or replace function public._has_open_room(u uuid)
returns boolean language sql stable as $$
  select (select count(*) from room_members m join rooms r on r.id = m.room_id
          where m.user_id = u and m.status = 'joined'
            and public._room_is_open(r, now())) >= 5
$$;

-- 이미 들어가 있는 방의 초대 코드를 다시 열면 오류 대신 그 방을 돌려준다.
create or replace function public._join_room_at(code text, nick text, u uuid, at timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
begin
  select * into rm from rooms where invite_code = upper(code) for update;
  if not found then raise exception 'invite_not_found'; end if;
  if exists (select 1 from room_members where room_id = rm.id and user_id = u and status = 'joined') then
    return rm.id;
  end if;
  if rm.status <> 'recruiting' or at > rm.recruit_expires_at then raise exception 'invite_closed'; end if;
  if (select count(*) from room_members where room_id = rm.id and status = 'joined') >= 4 then
    raise exception 'room_full';
  end if;
  if _has_open_room(u) then raise exception 'already_in_room'; end if;
  insert into room_members (room_id, user_id, nickname, nickname_no)
  values (rm.id, u, nick, _next_nickname_no(rm.id, nick));
  return rm.id;
end $$;

-- 내가 들어가 있는 열린 방 전부, 최근에 만든 방부터.
-- 예전 앱이 쓰는 my_room_id()는 그대로 둔다 (가장 최근 방 하나).
create or replace function public.my_room_ids()
returns table (id uuid) language sql stable security definer set search_path = public as $$
  select r.id from rooms r join room_members m on m.room_id = r.id
  where m.user_id = auth.uid() and m.status = 'joined'
    and public._room_is_open(r, now())
  order by r.created_at desc
$$;

grant execute on function public.my_room_ids() to authenticated;
