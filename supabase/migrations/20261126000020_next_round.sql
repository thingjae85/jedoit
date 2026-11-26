-- 끝난 챌린지 "다시 하기": 같은 친구들과 다음 회차 방을 한 번에 만든다.
-- 회차끼리는 prev_room_id로 이어지고, 기록 탭에서 지난 챌린지(진행도·단톡방·인증)를 모두 다시 볼 수 있다.

alter table public.rooms add column if not exists prev_room_id uuid references public.rooms(id) on delete set null;
alter table public.rooms add column if not exists round int not null default 1;
-- 한 방의 다음 회차는 하나뿐이다 (두 사람이 동시에 눌러도 방이 둘 생기지 않게).
create unique index if not exists rooms_next_round_once on public.rooms (prev_room_id) where prev_room_id is not null;

-- 다음 회차 시작. 설정(인증 방식·종류·이름·기간)은 앱에서 지난 회차 값을 채워 두고 고칠 수 있다.
-- 누른 사람이 새 방의 방장이 되고, 지난 회차 친구들은 같은 닉네임으로 함께 들어온다
-- (이미 열린 방이 가득한 친구는 빼고, 그 친구는 초대 코드로 나중에 들어올 수 있다).
-- 방은 모집 상태로 만들어지고, 방장이 시작을 확정하는 흐름은 처음 방과 같다.
create or replace function public.restart_room(prev uuid, nick text, mode text default 'result',
  category text default 'tidy', title text default '책상 한 구역 정리', days int default 3)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  u uuid := auth.uid();
  p rooms;
  nr rooms;
  existing rooms;
  t text := btrim(title);
  m record;
begin
  if u is null then raise exception 'not_authenticated'; end if;
  select * into p from rooms where id = prev for update;
  if not found or not exists (select 1 from room_members where room_id = prev and user_id = u and status = 'joined') then
    raise exception 'not_member';
  end if;
  if p.starts_at is null or p.ends_at is null or p.ends_at > now() then raise exception 'room_not_finished'; end if;

  -- 이미 다른 친구가 다음 회차를 열었으면 그 방으로 간다.
  select * into existing from rooms where prev_room_id = prev;
  if found then
    if exists (select 1 from room_members where room_id = existing.id and user_id = u and status = 'joined') then
      return existing.id;
    end if;
    return _join_room_at(existing.invite_code, nick, u, now());
  end if;

  if mode not in ('result', 'before_after', 'light') then raise exception 'bad_mode'; end if;
  if category not in ('tidy', 'reading', 'study', 'exercise', 'custom') then raise exception 'bad_category'; end if;
  if t is null or char_length(t) not between 2 and 20 then raise exception 'bad_title'; end if;
  if days is null or days not between 1 and 60 then raise exception 'bad_days'; end if;
  if _has_open_room(u) then raise exception 'already_in_room'; end if;

  insert into rooms (host_id, checkin_mode, category, title, days, prev_room_id, round)
  values (u, mode, category, t, days, prev, p.round + 1) returning * into nr;
  -- 방 설정 중 이 파일이 모르는 값(예: 다른 마이그레이션이 더한 열)도 지난 회차를 따른다.
  if to_jsonb(p) ? 'capture_only' then
    execute 'update rooms set capture_only = $1 where id = $2'
      using (to_jsonb(p)->>'capture_only')::boolean, nr.id;
  end if;

  insert into room_members (room_id, user_id, nickname) values (nr.id, u, nick);
  for m in
    select rm.user_id, rm.nickname from room_members rm
    where rm.room_id = prev and rm.status = 'joined' and rm.user_id is not null and rm.user_id <> u
    order by rm.joined_at
  loop
    exit when (select count(*) from room_members where room_id = nr.id and status = 'joined') >= 4;
    continue when _has_open_room(m.user_id);
    insert into room_members (room_id, user_id, nickname, nickname_no)
    values (nr.id, m.user_id, m.nickname, _next_nickname_no(nr.id, m.nickname));
  end loop;
  return nr.id;
end $$;

-- 기록 탭의 챌린지 기록: 내가 참여한(나가지 않은) 모든 챌린지, 최근에 만든 방부터.
-- 시작도 못 하고 취소·만료된 방은 뺀다. 방을 누르면 방 화면에서 진행도·단톡방·인증을 다시 볼 수 있다.
create or replace function public.my_challenge_history()
returns table (id uuid, round int, status public.room_status, category text, title text, days int,
               starts_at timestamptz, ends_at timestamptz, goal int, earned int, goal_reached_at timestamptz,
               member_count int, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.round, r.status, r.category, r.title, r.days, r.starts_at, r.ends_at, r.goal, r.earned,
         r.goal_reached_at,
         (select count(*)::int from room_members x where x.room_id = r.id and x.status = 'joined'),
         r.created_at
  from rooms r join room_members m on m.room_id = r.id
  where m.user_id = auth.uid() and m.status = 'joined'
    and (r.starts_at is not null or public._room_is_open(r, now()))
  order by r.created_at desc
  limit 200
$$;

-- 챌린지 탭의 "끝난 챌린지": 최근 7일 안에 끝났고 아직 다음 회차가 없는 내 방. 여기서 바로 다시 할 수 있다.
create or replace function public.my_finished_room_ids()
returns table (id uuid) language sql stable security definer set search_path = public as $$
  select r.id from rooms r join room_members m on m.room_id = r.id
  where m.user_id = auth.uid() and m.status = 'joined'
    and r.starts_at is not null and r.ends_at is not null
    and r.ends_at <= now() and r.ends_at > now() - interval '7 days'
    and not exists (select 1 from rooms n where n.prev_room_id = r.id)
  order by r.ends_at desc
$$;

-- 방 화면에서 쓰는 회차 정보: 몇 회차인지와, 다음 회차가 열렸으면 그 방(내가 들어가 있을 때만).
create or replace function public.room_round(r uuid)
returns table (round int, next_room_id uuid)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select x.round,
         (select n.id from rooms n join room_members m on m.room_id = n.id
          where n.prev_room_id = x.id and m.user_id = auth.uid() and m.status = 'joined')
  from rooms x where x.id = r;
end $$;
