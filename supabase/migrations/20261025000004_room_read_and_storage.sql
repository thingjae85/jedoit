-- 방 화면 조회 함수와 인증 사진 저장소(비공개 버킷) 설정

-- 초대 링크를 연 사람이 참가 전에 볼 수 있는 최소 정보 (닉네임·계정 정보 없음)
create or replace function public.invite_preview(code text)
returns table (room_id uuid, status public.room_status, member_count int, recruit_expires_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.status,
         (select count(*)::int from room_members m where m.room_id = r.id and m.status = 'joined'),
         r.recruit_expires_at
  from rooms r where r.invite_code = upper(code)
$$;

-- 내가 들어가 있는 모집·예약·진행 방 (사용자당 최대 1개)
create or replace function public.my_room_id()
returns uuid language sql stable security definer set search_path = public as $$
  select r.id from rooms r join room_members m on m.room_id = r.id
  where m.user_id = auth.uid() and m.status = 'joined'
    and r.status in ('recruiting', 'scheduled', 'active')
  order by r.created_at desc limit 1
$$;

-- 방 화면에 필요한 값을 한 번에: 상태·시각·T·G·H·현재 유효 인증 수 C
create or replace function public.room_summary(r uuid)
returns table (
  id uuid, status public.room_status, invite_code text, is_host boolean,
  recruit_expires_at timestamptz, starts_at timestamptz, ends_at timestamptz,
  n0 int, active_count int, total_elements int, goal int, earned int, valid_count int,
  goal_reached_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select rm.id, rm.status, rm.invite_code, rm.host_id = auth.uid(),
         rm.recruit_expires_at, rm.starts_at, rm.ends_at,
         rm.n0, t.active_count, t.total_elements, rm.goal, rm.earned,
         (select count(*)::int from checkin_slots c where c.room_id = rm.id and c.valid),
         rm.goal_reached_at
  from rooms rm, room_targets(r) t
  where rm.id = r;
end $$;

-- 방 참가자 목록: 방 전용 닉네임만 (Google 이름·이메일 없음)
create or replace function public.room_members_view(r uuid)
returns table (nickname text, nickname_no int, is_me boolean, is_host boolean, checkins int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_active_member(r) then raise exception 'not_member'; end if;
  return query
  select m.nickname, m.nickname_no, m.user_id = auth.uid(), m.user_id = rm.host_id,
         (select count(*)::int from checkin_slots c
          where c.room_id = r and c.user_id = m.user_id and c.valid)
  from room_members m join rooms rm on rm.id = m.room_id
  where m.room_id = r and m.status = 'joined'
  order by m.joined_at;
end $$;

-- 인증 사진: 비공개 버킷, JPEG만, 1MiB 이하
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('checkins', 'checkins', false, 1048576, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = 1048576, allowed_mime_types = array['image/jpeg'];

-- 올리기: 서버가 발급한, 아직 쓰지 않고 만료되지 않은 내 경로에만 새 파일 생성
create policy "checkin upload via ticket" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'checkins'
    and exists (select 1 from public.upload_tickets t
                where t.path = name and t.user_id = auth.uid()
                  and not t.used and t.expires_at > now())
  );

-- 보기: 그 방의 현재 참가자만 (경로 첫 부분이 방 ID)
create policy "checkin read by members" on storage.objects
  for select to authenticated
  using (bucket_id = 'checkins' and public.is_active_member(((storage.foldername(name))[1])::uuid));
