-- 10단계: 시작일을 방장이 고른다 — 오늘부터(오늘이 1일차) 또는 내일 0시부터.
-- 저녁 늦게 확정해서 하루를 손해 보지 않도록 내일 시작을 고를 수 있다.

drop function if exists public.confirm_start(uuid);
drop function if exists public._confirm_start_at(uuid, uuid, timestamptz);

create or replace function public._confirm_start_at(r uuid, u uuid, at timestamptz, tomorrow boolean)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  n int;
  start_ts timestamptz := ((kst_date(at) + case when tomorrow then 1 else 0 end)::timestamp at time zone 'Asia/Seoul');
begin
  select * into rm from rooms where id = r for update;
  if rm.host_id <> u then raise exception 'not_host'; end if;
  if rm.status <> 'recruiting' or at > rm.recruit_expires_at then raise exception 'not_recruiting'; end if;
  select count(*) into n from room_members where room_id = r and status = 'joined';
  if n < 2 then raise exception 'need_two_members'; end if;
  update rooms set status = case when tomorrow then 'scheduled'::room_status else 'active'::room_status end,
                   starts_at = start_ts, ends_at = start_ts + make_interval(days => rm.days),
                   n0 = n, goal = _goal_per_person(rm.days) * n
  where id = r returning * into rm;
  return rm;
end $$;

create or replace function public.confirm_start(r uuid, tomorrow boolean default false)
returns public.rooms language sql security definer set search_path = public as $$
  select public._confirm_start_at(r, auth.uid(), now(), coalesce(tomorrow, false))
$$;

revoke execute on function public._confirm_start_at from public, anon, authenticated;
