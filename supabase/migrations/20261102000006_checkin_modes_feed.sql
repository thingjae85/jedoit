-- 방 인증 방식(결과·전후·가벼운), 동영상, 방 피드

-- 방장이 방을 만들 때 고르는 인증 방식
alter table public.rooms add column if not exists checkin_mode text not null default 'result'
  check (checkin_mode in ('result', 'before_after', 'light'));

-- 인증 슬롯: 결과는 사진 또는 동영상, 전후는 전 사진·한 줄을 따로 둔다
alter table public.checkin_slots add column if not exists media_type text not null default 'photo'
  check (media_type in ('photo', 'video', 'none'));
alter table public.checkin_slots add column if not exists before_path text;
alter table public.checkin_slots add column if not exists before_note text;

-- 전후 인증의 '전' 단계: 정리 시작할 때 찍어 두고, '후'를 올릴 때 인증 슬롯으로 합친다
create table if not exists public.checkin_befores (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  slot_date date not null,
  path text not null,
  note text,
  created_at timestamptz not null default now(),
  primary key (room_id, user_id, slot_date)
);
alter table public.checkin_befores enable row level security;

-- 업로드 경로 발급: 확장자로 사진·동영상 구분. 전후 인증은 하루 두 장이 필요해서 하루 6회로 늘림
drop function if exists public.issue_upload(uuid);
drop function if exists public._issue_upload_at(uuid, uuid, timestamptz);
create function public._issue_upload_at(r uuid, u uuid, at timestamptz, ext text)
returns public.upload_tickets language plpgsql security definer set search_path = public as $$
declare
  d date := kst_date(at);
  midnight timestamptz := ((d + 1)::timestamp at time zone 'Asia/Seoul');
  t upload_tickets;
begin
  if ext not in ('jpg', 'mp4', 'mov') then raise exception 'bad_media'; end if;
  if not exists (select 1 from room_members where room_id = r and user_id = u and status = 'joined') then
    raise exception 'not_member';
  end if;
  if (select count(*) from upload_tickets where room_id = r and user_id = u and slot_date = d) >= 6 then
    raise exception 'upload_limit';
  end if;
  insert into upload_tickets (room_id, user_id, slot_date, path, expires_at)
  values (r, u, d, r || '/' || u || '/' || d || '/' || gen_random_uuid() || '.' || ext,
          least(at + interval '5 minutes', midnight))
  returning * into t;
  return t;
end $$;

create function public.issue_upload(r uuid, ext text default 'jpg')
returns public.upload_tickets language sql security definer set search_path = public as $$
  select public._issue_upload_at(r, auth.uid(), now(), ext)
$$;

-- 발급 경로를 확인하고 사용 처리한다 (날짜가 바뀌면 실패)
create or replace function public._use_ticket(r uuid, u uuid, ticket uuid, at timestamptz)
returns public.upload_tickets language plpgsql security definer set search_path = public as $$
declare
  t upload_tickets;
begin
  select * into t from upload_tickets where id = ticket and user_id = u and room_id = r for update;
  if not found or t.used then raise exception 'invalid_ticket'; end if;
  if t.slot_date <> kst_date(at) or at > t.expires_at then raise exception 'date_changed'; end if;
  update upload_tickets set used = true where id = ticket;
  return t;
end $$;

-- 전후 인증 '전' 저장 (같은 날 다시 찍으면 바꿔 끼움)
create or replace function public._save_before_at(r uuid, u uuid, ticket uuid, note text, at timestamptz)
returns text language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  t upload_tickets;
  old_path text;
begin
  select * into rm from rooms where id = r;
  if rm.checkin_mode <> 'before_after' then raise exception 'wrong_mode'; end if;
  t := _use_ticket(r, u, ticket, at);
  select path into old_path from checkin_befores where room_id = r and user_id = u and slot_date = t.slot_date;
  insert into checkin_befores (room_id, user_id, slot_date, path, note)
  values (r, u, t.slot_date, t.path, left(note, 100))
  on conflict (room_id, user_id, slot_date) do update set path = excluded.path, note = excluded.note, created_at = now();
  return old_path; -- 바꿔 낀 예전 '전' 사진은 앱이 지운다
end $$;

create or replace function public.save_before(r uuid, ticket uuid, note text)
returns text language sql security definer set search_path = public as $$
  select public._save_before_at(r, auth.uid(), ticket, note, now())
$$;

-- 오늘 찍어 둔 '전' 사진 (전후 인증 화면에서 보여 줌)
create or replace function public.my_before_today(r uuid)
returns table (path text, note text)
language sql stable security definer set search_path = public as $$
  select b.path, b.note from checkin_befores b
  where b.room_id = r and b.user_id = auth.uid() and b.slot_date = kst_date(now())
$$;

-- 인증 저장: 방 인증 방식에 맞는지 확인. 가벼운 인증은 파일 없이 한 줄만
drop function if exists public.submit_checkin(uuid, uuid, text);
drop function if exists public._submit_checkin_at(uuid, uuid, uuid, text, timestamptz);
create function public._submit_checkin_at(r uuid, u uuid, ticket uuid, note text, at timestamptz)
returns public.checkin_slots language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  t upload_tickets;
  b checkin_befores;
  s checkin_slots;
  a int;
  d date := kst_date(at);
  media text := 'none';
  file_path text;
begin
  select * into rm from rooms where id = r for update;
  if rm.status = 'scheduled' and at >= rm.starts_at then
    update rooms set status = 'active' where id = r returning * into rm;
  end if;
  if rm.status <> 'active' or at >= rm.ends_at then raise exception 'room_not_active'; end if;
  if not exists (select 1 from room_members where room_id = r and user_id = u and status = 'joined') then
    raise exception 'not_member';
  end if;

  if rm.checkin_mode = 'light' then
    if coalesce(trim(note), '') = '' then raise exception 'note_required'; end if;
  else
    if ticket is null then raise exception 'media_required'; end if;
    t := _use_ticket(r, u, ticket, at);
    d := t.slot_date;
    file_path := t.path;
    media := case when t.path like '%.jpg' then 'photo' else 'video' end;
    if rm.checkin_mode = 'before_after' then
      if media <> 'photo' then raise exception 'bad_media'; end if;
      select * into b from checkin_befores where room_id = r and user_id = u and slot_date = d;
      if not found then raise exception 'before_required'; end if;
    end if;
  end if;

  insert into checkin_slots as cs
    (room_id, user_id, slot_date, photo_path, memo, checked_at, media_type, before_path, before_note)
  values (r, u, d, file_path, left(note, 100), at, media, b.path, b.note)
  on conflict (room_id, user_id, slot_date) do update
    set valid = true, photo_path = excluded.photo_path, memo = excluded.memo, checked_at = excluded.checked_at,
        media_type = excluded.media_type, before_path = excluded.before_path, before_note = excluded.before_note
    where not cs.valid
  returning * into s;
  if s is null then raise exception 'already_checked_in'; end if;
  delete from checkin_befores where room_id = r and user_id = u and slot_date = d;

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

create function public.submit_checkin(r uuid, ticket uuid, note text)
returns public.checkin_slots language sql security definer set search_path = public as $$
  select public._submit_checkin_at(r, auth.uid(), ticket, note, now())
$$;

-- 방 만들기: 인증 방식 선택
drop function if exists public.create_room(text);
create function public.create_room(nick text, mode text default 'result')
returns public.rooms language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  new_room rooms;
begin
  if u is null then raise exception 'not_authenticated'; end if;
  if mode not in ('result', 'before_after', 'light') then raise exception 'bad_mode'; end if;
  if _has_open_room(u) then raise exception 'already_in_room'; end if;
  insert into rooms (host_id, checkin_mode) values (u, mode) returning * into new_room;
  insert into room_members (room_id, user_id, nickname) values (new_room.id, u, nick);
  return new_room;
end $$;

-- 방 요약에 인증 방식 추가
drop function if exists public.room_summary(uuid);
create function public.room_summary(r uuid)
returns table (
  id uuid, status public.room_status, invite_code text, is_host boolean,
  recruit_expires_at timestamptz, starts_at timestamptz, ends_at timestamptz,
  n0 int, active_count int, total_elements int, goal int, earned int, valid_count int,
  goal_reached_at timestamptz, checkin_mode text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select rm.id, rm.status, rm.invite_code, rm.host_id = auth.uid(),
         rm.recruit_expires_at, rm.starts_at, rm.ends_at,
         rm.n0, t.active_count, t.total_elements, rm.goal, rm.earned,
         (select count(*)::int from checkin_slots c where c.room_id = rm.id and c.valid),
         rm.goal_reached_at, rm.checkin_mode
  from rooms rm, room_targets(r) t
  where rm.id = r;
end $$;

-- 방 피드: 현재 참가자들의 유효 인증, 최신순. 닉네임만 보이고 계정 정보는 없음
create or replace function public.room_feed(r uuid)
returns table (
  nickname text, nickname_no int, is_me boolean, slot_date date, checked_at timestamptz,
  media_type text, media_path text, note text, before_path text, before_note text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select m.nickname, m.nickname_no, m.user_id = auth.uid(), c.slot_date, c.checked_at,
         c.media_type, c.photo_path, c.memo, c.before_path, c.before_note
  from checkin_slots c join room_members m on m.room_id = c.room_id and m.user_id = c.user_id
  where c.room_id = r and c.valid and m.status = 'joined'
  order by c.checked_at desc;
end $$;

-- 사진 삭제·인증 취소: 전 사진까지 함께 지우고, 지울 파일 경로들을 돌려준다
drop function if exists public.delete_checkin_photo(uuid, date);
create function public.delete_checkin_photo(r uuid, d date)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  paths text[];
begin
  select array_remove(array[photo_path, before_path], null) into paths from checkin_slots
  where room_id = r and user_id = auth.uid() and slot_date = d for update;
  update checkin_slots set photo_path = null, memo = null, before_path = null, before_note = null
  where room_id = r and user_id = auth.uid() and slot_date = d;
  return coalesce(paths, '{}');
end $$;

drop function if exists public.cancel_checkin(uuid, date);
create function public.cancel_checkin(r uuid, d date)
returns text[] language plpgsql security definer set search_path = public as $$
declare
  paths text[];
begin
  select array_remove(array[photo_path, before_path], null) into paths from checkin_slots
  where room_id = r and user_id = auth.uid() and slot_date = d for update;
  update checkin_slots set valid = false, photo_path = null, memo = null, before_path = null, before_note = null
  where room_id = r and user_id = auth.uid() and slot_date = d;
  return coalesce(paths, '{}');
end $$;

-- my_checkins: 전 사진도 '사진 있음'으로
create or replace function public.my_checkins(r uuid)
returns table (slot_date date, valid boolean, has_photo boolean, memo text, checked_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.slot_date, c.valid, c.photo_path is not null or c.before_path is not null, c.memo, c.checked_at
  from checkin_slots c
  where c.room_id = r and c.user_id = auth.uid()
  order by c.slot_date
$$;

-- 계정 삭제 접수 시 전후 사진도 비공개
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
  select due_at into due from deletion_requests
  where user_id = u and scope = 'account' and done_at is null;
  if due is null then
    insert into deletion_requests (user_id, scope) values (u, 'account') returning due_at into due;
  end if;
  return due;
end $$;

-- 버킷: 동영상(mp4·mov) 허용, 파일 하나 20MiB까지 (사진은 앱이 1MiB 이하로 줄여 올림)
update storage.buckets
  set file_size_limit = 20971520, allowed_mime_types = array['image/jpeg', 'video/mp4', 'video/quicktime']
  where id = 'checkins';

revoke execute on function public._issue_upload_at, public._submit_checkin_at, public._save_before_at,
  public._use_ticket from public, anon, authenticated;
