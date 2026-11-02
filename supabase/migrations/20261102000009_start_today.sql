-- 9단계: 시작을 확정하면 오늘부터 바로 시작한다 (오늘이 1일차).
-- 시연하면서 바로 인증·피드·응원을 볼 수 있게 한다. 끝나는 시각은 오늘 00:00 KST + 기간.

create or replace function public._confirm_start_at(r uuid, u uuid, at timestamptz)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare
  rm rooms;
  n int;
  start_ts timestamptz := (kst_date(at)::timestamp at time zone 'Asia/Seoul');
begin
  select * into rm from rooms where id = r for update;
  if rm.host_id <> u then raise exception 'not_host'; end if;
  if rm.status <> 'recruiting' or at > rm.recruit_expires_at then raise exception 'not_recruiting'; end if;
  select count(*) into n from room_members where room_id = r and status = 'joined';
  if n < 2 then raise exception 'need_two_members'; end if;
  update rooms set status = 'active', starts_at = start_ts, ends_at = start_ts + make_interval(days => rm.days),
                   n0 = n, goal = _goal_per_person(rm.days) * n
  where id = r returning * into rm;
  return rm;
end $$;

revoke execute on function public._confirm_start_at from public, anon, authenticated;
