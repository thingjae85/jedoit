-- 인증 동영상을 소리와 함께 보여 줄지 올린 사람이 고른다. 기본은 음소거.
alter table public.checkin_slots add column if not exists video_sound boolean not null default false;

-- 방금 올린 내 인증 동영상의 소리 여부를 정한다.
create or replace function public.set_checkin_sound(r uuid, d date, sound boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  update checkin_slots set video_sound = sound
   where room_id = r and user_id = auth.uid() and slot_date = d;
end $$;

-- 피드에 소리 여부를 함께 돌려준다 (반환 열이 늘어 다시 만든다).
drop function if exists public.room_feed(uuid);
create function public.room_feed(r uuid)
returns table(nickname text, nickname_no integer, is_me boolean, slot_date date, checked_at timestamptz,
              media_type text, media_path text, note text, before_path text, before_note text,
              clap_count integer, fire_count integer, my_clap boolean, my_fire boolean, video_sound boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select m.nickname, m.nickname_no, m.user_id = auth.uid(), c.slot_date, c.checked_at,
         c.media_type, c.photo_path, c.memo, c.before_path, c.before_note,
         coalesce(x.claps, 0), coalesce(x.fires, 0), coalesce(x.my_clap, false), coalesce(x.my_fire, false),
         c.video_sound
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
