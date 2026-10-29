-- 4단계: 내 인증 목록, 사진 삭제, 인증 취소, 계정 삭제 접수

-- 내 인증 목록 (방 안에서 내 것만)
create or replace function public.my_checkins(r uuid)
returns table (slot_date date, valid boolean, has_photo boolean, memo text, checked_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.slot_date, c.valid, c.photo_path is not null, c.memo, c.checked_at
  from checkin_slots c
  where c.room_id = r and c.user_id = auth.uid()
  order by c.slot_date
$$;

-- 사진·메모 삭제: 완료 체크와 획득 보상은 유지. 지울 파일 경로를 돌려준다.
create or replace function public.delete_checkin_photo(r uuid, d date)
returns text language plpgsql security definer set search_path = public as $$
declare
  old_path text;
begin
  select photo_path into old_path from checkin_slots
  where room_id = r and user_id = auth.uid() and slot_date = d for update;
  update checkin_slots set photo_path = null, memo = null
  where room_id = r and user_id = auth.uid() and slot_date = d;
  return old_path;
end $$;

-- 인증 취소: 완료 체크 무효(C 감소)와 사진·메모 제거. 획득 보상 H는 유지.
drop function if exists public.cancel_checkin(uuid, date);
create function public.cancel_checkin(r uuid, d date)
returns text language plpgsql security definer set search_path = public as $$
declare
  old_path text;
begin
  select photo_path into old_path from checkin_slots
  where room_id = r and user_id = auth.uid() and slot_date = d for update;
  update checkin_slots set valid = false, photo_path = null, memo = null
  where room_id = r and user_id = auth.uid() and slot_date = d;
  return old_path;
end $$;

-- 계정 삭제 접수: 참가 종료(이탈 산식 적용), 현재 인증 집계·사진 목록에서 제외, 7일 이내 실제 삭제
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
  update checkin_slots set valid = false, photo_path = null, memo = null where user_id = u;
  select due_at into due from deletion_requests
  where user_id = u and scope = 'account' and done_at is null;
  if due is null then
    insert into deletion_requests (user_id, scope) values (u, 'account') returning due_at into due;
  end if;
  return due;
end $$;

-- 내 사진 파일은 내가 지울 수 있다 (경로: 방/사용자/날짜/파일)
create policy "checkin delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'checkins' and (storage.foldername(name))[2] = auth.uid()::text);
