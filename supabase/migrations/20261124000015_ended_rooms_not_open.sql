-- 기간이 끝난 방(끝나는 시각이 지남)과 모집 기한이 지난 방은 "참여 중인 방"으로 치지 않는다.
-- 서버의 방 상태는 끝나는 시각이 지나도 'active'로 남아 있어서,
-- 끝난 방의 참가자가 새 방을 만들거나 다른 방에 들어가지 못하던 문제를 고친다.

create or replace function public._room_is_open(r public.rooms, at timestamptz)
returns boolean language sql stable as $$
  select case r.status
    when 'recruiting' then r.recruit_expires_at is null or r.recruit_expires_at > at
    when 'scheduled'  then r.ends_at is null or r.ends_at > at
    when 'active'     then r.ends_at is null or r.ends_at > at
    else false
  end
$$;

create or replace function public._has_open_room(u uuid)
returns boolean language sql stable as $$
  select exists (select 1 from room_members m join rooms r on r.id = m.room_id
                 where m.user_id = u and m.status = 'joined'
                   and public._room_is_open(r, now()))
$$;

create or replace function public.my_room_id()
returns uuid language sql stable security definer set search_path = public as $$
  select r.id from rooms r join room_members m on m.room_id = r.id
  where m.user_id = auth.uid() and m.status = 'joined'
    and public._room_is_open(r, now())
  order by r.created_at desc limit 1
$$;
