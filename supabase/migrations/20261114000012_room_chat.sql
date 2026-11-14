-- 12단계: 챌린지방 단톡방
-- 방 참가자끼리 글로 이야기를 나눈다. 참가 중(joined)인 사람만 읽고 쓸 수 있다.
-- 새 메시지는 Supabase Realtime으로 바로 전달된다(앱은 10초마다 한 번 더 확인한다).

create table if not exists public.room_messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists room_messages_room_id_idx on public.room_messages (room_id, id);

alter table public.room_messages enable row level security;

-- 읽기: 방 참가자만. Realtime도 이 정책으로 받을 사람을 거른다.
drop policy if exists "members read messages" on public.room_messages;
create policy "members read messages" on public.room_messages
  for select using (public.is_active_member(room_id));
-- 쓰기 정책 없음: 아래 send_room_message 함수로만 쓴다.

-- Realtime 켜기 (이미 켜져 있으면 넘어간다)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_messages'
  ) then
    alter publication supabase_realtime add table public.room_messages;
  end if;
end $$;

-- 메시지 보내기. 앞뒤 공백을 지우고 1~500자만 받는다. 새 메시지 번호를 돌려준다.
create or replace function public.send_room_message(r uuid, body text)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  msg text := btrim(coalesce(body, ''));
  new_id bigint;
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  if char_length(msg) = 0 then raise exception 'empty_message'; end if;
  if char_length(msg) > 500 then raise exception 'message_too_long'; end if;
  insert into room_messages (room_id, user_id, body)
  values (r, auth.uid(), msg)
  returning id into new_id;
  return new_id;
end $$;

-- 메시지 읽기: [after]번 다음 메시지부터, 최근 200개를 오래된 순으로.
create or replace function public.room_chat(r uuid, after bigint default 0)
returns table (id bigint, nickname text, nickname_no int, is_me boolean, body text, sent_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select x.id, x.nickname, x.nickname_no, x.is_me, x.body, x.sent_at from (
    select g.id, coalesce(m.nickname, '떠난 친구') as nickname, coalesce(m.nickname_no, 1) as nickname_no,
           g.user_id = auth.uid() as is_me, g.body, g.created_at as sent_at
    from room_messages g
    left join room_members m on m.room_id = g.room_id and m.user_id = g.user_id
    where g.room_id = r and g.id > coalesce(after, 0)
    order by g.id desc
    limit 200
  ) x
  order by x.id;
end $$;

-- 계정을 지우면(room_members.status = 'deleted') 그 사람이 쓴 메시지도 지운다
create or replace function public._delete_messages_of_deleted_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.user_id is not null then
    delete from room_messages where user_id = new.user_id;
  end if;
  return new;
end $$;

drop trigger if exists room_members_deleted_messages on public.room_members;
create trigger room_members_deleted_messages
  after update of status on public.room_members
  for each row when (new.status = 'deleted' and old.status is distinct from 'deleted')
  execute function public._delete_messages_of_deleted_member();
