-- 18단계: 단톡방 반응과 답장
-- 메시지에 이모지 반응을 달고, 메시지나 참가자 인증에 답장(댓글)을 쓸 수 있다.
-- 인증에 단 답장은 그 인증의 댓글로 모아 보여 준다.

-- 답장 대상: 메시지(reply_to) 또는 인증(reply_owner + reply_date) 중 하나
alter table public.room_messages
  add column if not exists reply_to bigint references public.room_messages(id) on delete set null,
  add column if not exists reply_owner uuid,
  add column if not exists reply_date date;

-- 메시지 반응. 한 사람이 한 메시지에 이모지마다 한 번씩 누를 수 있고, 다시 누르면 취소된다.
create table if not exists public.room_message_reactions (
  message_id bigint not null references public.room_messages(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (emoji in ('heart', 'like', 'laugh', 'wow', 'sad', 'clap')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);
create index if not exists room_message_reactions_room_idx on public.room_message_reactions (room_id);

alter table public.room_message_reactions enable row level security;
-- 읽기: 방 참가자만 (Realtime도 이 정책으로 거른다). 쓰기는 아래 함수로만.
drop policy if exists "members read message reactions" on public.room_message_reactions;
create policy "members read message reactions" on public.room_message_reactions
  for select using (public.is_active_member(room_id));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'room_message_reactions'
  ) then
    alter publication supabase_realtime add table public.room_message_reactions;
  end if;
end $$;

-- 메시지 보내기: 답장 대상을 함께 받는다. 인증은 닉네임·번호·날짜로 가리킨다(방 피드와 같은 방식).
drop function if exists public.send_room_message(uuid, text);
create or replace function public.send_room_message(r uuid, body text, reply_to bigint default null,
  reply_nick text default null, reply_nick_no int default null, reply_date date default null)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  msg text := btrim(coalesce(body, ''));
  target bigint := null;
  owner uuid := null;
  new_id bigint;
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  if char_length(msg) = 0 then raise exception 'empty_message'; end if;
  if char_length(msg) > 500 then raise exception 'message_too_long'; end if;
  if send_room_message.reply_to is not null then
    select g.id into target from room_messages g where g.id = send_room_message.reply_to and g.room_id = r;
    if target is null then raise exception 'reply_not_found'; end if;
  elsif reply_nick is not null and reply_date is not null then
    select m.user_id into owner
    from room_members m
    join checkin_slots c on c.room_id = m.room_id and c.user_id = m.user_id
    where m.room_id = r and m.nickname = reply_nick and m.nickname_no = coalesce(reply_nick_no, 1)
      and m.status = 'joined' and c.slot_date = send_room_message.reply_date and c.valid;
    if owner is null then raise exception 'checkin_not_found'; end if;
  end if;
  insert into room_messages (room_id, user_id, body, reply_to, reply_owner, reply_date)
  values (r, auth.uid(), msg, target, owner, case when owner is null then null else send_room_message.reply_date end)
  returning id into new_id;
  return new_id;
end $$;

-- 메시지 읽기: 답장 대상을 함께 돌려준다. 인증 답장은 지금 닉네임으로 바꿔 준다.
drop function if exists public.room_chat(uuid, bigint);
create function public.room_chat(r uuid, after bigint default 0)
returns table (id bigint, nickname text, nickname_no int, is_me boolean, body text, sent_at timestamptz,
  reply_to bigint, reply_nick text, reply_nick_no int, reply_date date)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select x.* from (
    select g.id, coalesce(m.nickname, '떠난 친구') as nickname, coalesce(m.nickname_no, 1) as nickname_no,
           g.user_id = auth.uid() as is_me, g.body, g.created_at as sent_at,
           g.reply_to, o.nickname as reply_nick, o.nickname_no as reply_nick_no, g.reply_date
    from room_messages g
    left join room_members m on m.room_id = g.room_id and m.user_id = g.user_id
    left join room_members o on o.room_id = g.room_id and o.user_id = g.reply_owner
    where g.room_id = r and g.id > coalesce(after, 0)
    order by g.id desc
    limit 200
  ) x
  order by x.id;
end $$;

-- 반응 누르기/취소. 눌린 상태가 되면 true.
create or replace function public.toggle_message_reaction(r uuid, m bigint, emoji text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  if emoji not in ('heart', 'like', 'laugh', 'wow', 'sad', 'clap') then raise exception 'bad_reaction'; end if;
  if not exists (select 1 from room_messages g where g.id = m and g.room_id = r) then
    raise exception 'message_not_found';
  end if;
  delete from room_message_reactions k
  where k.message_id = m and k.user_id = me and k.emoji = toggle_message_reaction.emoji;
  if found then return false; end if;
  insert into room_message_reactions (message_id, room_id, user_id, emoji)
  values (m, r, me, toggle_message_reaction.emoji);
  return true;
end $$;

-- 최근 메시지(200개)의 반응: 메시지·이모지별 수와 내가 눌렀는지
create or replace function public.room_chat_reactions(r uuid)
returns table (message_id bigint, emoji text, count int, mine boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select k.message_id, k.emoji, count(*)::int, bool_or(k.user_id = auth.uid())
  from room_message_reactions k
  where k.room_id = r
    and k.message_id >= coalesce((select min(y.id) from (
      select g.id from room_messages g where g.room_id = r order by g.id desc limit 200) y), 0)
  group by k.message_id, k.emoji;
end $$;

-- 계정을 지우면 그 사람이 쓴 메시지와 단 반응도 지운다
create or replace function public._delete_messages_of_deleted_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.user_id is not null then
    delete from room_message_reactions where user_id = new.user_id;
    delete from room_messages where user_id = new.user_id;
  end if;
  return new;
end $$;
