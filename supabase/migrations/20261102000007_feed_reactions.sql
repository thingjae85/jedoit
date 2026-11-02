-- 7단계: 방 피드 응원 리액션 (👏 clap, 🔥 fire)
-- 방 친구의 인증 카드에 종류별로 한 번씩 누를 수 있다. 다시 누르면 취소된다.

create table public.checkin_reactions (
  room_id uuid not null,
  owner_id uuid not null,
  slot_date date not null,
  reactor_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('clap', 'fire')),
  created_at timestamptz not null default now(),
  primary key (room_id, owner_id, slot_date, reactor_id, kind),
  foreign key (room_id, owner_id, slot_date)
    references public.checkin_slots (room_id, user_id, slot_date) on delete cascade
);
alter table public.checkin_reactions enable row level security;
-- 정책 없음: 아래 함수로만 읽고 쓴다.

-- 리액션 누르기/취소. 눌린 상태가 되면 true, 취소되면 false.
create or replace function public.toggle_reaction(r uuid, nick text, nick_no int, d date, emoji text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  owner uuid;
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  if emoji not in ('clap', 'fire') then raise exception 'bad_reaction'; end if;
  select m.user_id into owner
  from room_members m
  join checkin_slots c on c.room_id = m.room_id and c.user_id = m.user_id
  where m.room_id = r and m.nickname = nick and m.nickname_no = nick_no
    and m.status = 'joined' and c.slot_date = d and c.valid;
  if owner is null then raise exception 'checkin_not_found'; end if;
  if owner = me then raise exception 'own_checkin'; end if;

  delete from checkin_reactions
  where room_id = r and owner_id = owner and slot_date = d and reactor_id = me and kind = emoji;
  if found then return false; end if;
  insert into checkin_reactions (room_id, owner_id, slot_date, reactor_id, kind)
  values (r, owner, d, me, emoji);
  return true;
end $$;

-- 방 피드: 리액션 개수와 내가 눌렀는지를 함께 돌려준다
drop function if exists public.room_feed(uuid);
create function public.room_feed(r uuid)
returns table (
  nickname text, nickname_no int, is_me boolean, slot_date date, checked_at timestamptz,
  media_type text, media_path text, note text, before_path text, before_note text,
  clap_count int, fire_count int, my_clap boolean, my_fire boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select m.nickname, m.nickname_no, m.user_id = auth.uid(), c.slot_date, c.checked_at,
         c.media_type, c.photo_path, c.memo, c.before_path, c.before_note,
         coalesce(x.claps, 0), coalesce(x.fires, 0), coalesce(x.my_clap, false), coalesce(x.my_fire, false)
  from checkin_slots c
  join room_members m on m.room_id = c.room_id and m.user_id = c.user_id
  left join lateral (
    select count(*) filter (where k.kind = 'clap')::int as claps,
           count(*) filter (where k.kind = 'fire')::int as fires,
           bool_or(k.kind = 'clap' and k.reactor_id = auth.uid()) as my_clap,
           bool_or(k.kind = 'fire' and k.reactor_id = auth.uid()) as my_fire
    from checkin_reactions k
    where k.room_id = c.room_id and k.owner_id = c.user_id and k.slot_date = c.slot_date
  ) x on true
  where c.room_id = r and c.valid and m.status = 'joined'
  order by c.checked_at desc;
end $$;

-- 인증 취소하면 받은 리액션도 지운다
create or replace function public.cancel_checkin(r uuid, d date)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  paths text[];
begin
  select array_remove(array[photo_path, before_path], null) into paths from checkin_slots
  where room_id = r and user_id = auth.uid() and slot_date = d for update;
  update checkin_slots set valid = false, photo_path = null, memo = null, before_path = null, before_note = null
  where room_id = r and user_id = auth.uid() and slot_date = d;
  delete from checkin_reactions where room_id = r and owner_id = auth.uid() and slot_date = d;
  return coalesce(paths, '{}');
end $$;

-- 계정 삭제: 내가 누른 리액션과 받은 리액션도 지운다
create or replace function public.request_account_deletion()
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  rid uuid;
  due timestamptz;
begin
  if u is null then raise exception 'not_authenticated'; end if;
  for rid in select room_id from room_members where user_id = u and status = 'joined' loop
    perform _leave_room_at(rid, u, now());
  end loop;
  update room_members set status = 'deleted' where user_id = u;
  update checkin_slots set valid = false, photo_path = null, memo = null, before_path = null, before_note = null
  where user_id = u;
  delete from checkin_befores where user_id = u;
  delete from checkin_reactions where reactor_id = u or owner_id = u;
  select due_at into due from deletion_requests
  where user_id = u and scope = 'account' and done_at is null;
  if due is null then
    insert into deletion_requests (user_id, scope) values (u, 'account') returning due_at into due;
  end if;
  return due;
end $$;
