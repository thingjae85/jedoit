-- 챌린지 기간을 1일부터 정할 수 있게 한다 (기존 3일부터).
-- 1일짜리는 1인당 목표 1회라서, 모두 한 번씩 인증하면 바로 목표를 채운다.
alter table public.rooms drop constraint if exists rooms_days_check;
alter table public.rooms add constraint rooms_days_check check (days between 1 and 60);

create or replace function public.create_room(nick text, mode text default 'result',
  category text default 'tidy', title text default '책상 한 구역 정리', days int default 3)
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
  insert into rooms (host_id, checkin_mode, category, title, days)
  values (u, mode, category, t, days) returning * into new_room;
  insert into room_members (room_id, user_id, nickname) values (new_room.id, u, nick);
  return new_room;
end $$;
