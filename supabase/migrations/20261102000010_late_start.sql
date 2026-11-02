-- 10단계: 늦게 확정해도 하루를 손해 보지 않게
-- 한국 시간 18시 전에 확정하면 오늘 0시부터(오늘이 1일차), 18시 이후면 내일 0시에 시작한다.

create or replace function public._confirm_start_at(r uuid, u uuid, at timestamptz)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  n int;
  late boolean := extract(hour from (at at time zone 'Asia/Seoul')) >= 18;
  start_ts timestamptz := ((kst_date(at) + case when late then 1 else 0 end)::timestamp at time zone 'Asia/Seoul');
begin
  select * into rm from rooms where id = r for update;
  if rm.host_id <> u then raise exception 'not_host'; end if;
  if rm.status <> 'recruiting' or at > rm.recruit_expires_at then raise exception 'not_recruiting'; end if;
  select count(*) into n from room_members where room_id = r and status = 'joined';
  if n < 2 then raise exception 'need_two_members'; end if;
  update rooms set status = case when late then 'scheduled'::room_status else 'active'::room_status end,
                   starts_at = start_ts, ends_at = start_ts + make_interval(days => rm.days),
                   n0 = n, goal = _goal_per_person(rm.days) * n
  where id = r returning * into rm;
  return rm;
end $$;

revoke execute on function public._confirm_start_at from public, anon, authenticated;
