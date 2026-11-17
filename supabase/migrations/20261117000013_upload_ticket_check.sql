-- 인증 사진 업로드가 늘 막히던 문제.
-- 업로드 정책이 upload_tickets 를 직접 읽는데, 이 테이블은 RLS 가 켜져 있고 읽기 정책이 없어
-- 로그인한 사용자 권한으로는 발급 기록이 하나도 안 보였다. 확인을 security definer 함수로 옮긴다.
create or replace function public.has_upload_ticket(p text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from upload_tickets t
                 where t.path = p and t.user_id = auth.uid()
                   and not t.used and t.expires_at > now())
$$;

revoke all on function public.has_upload_ticket(text) from public, anon;
grant execute on function public.has_upload_ticket(text) to authenticated;

drop policy if exists "checkin upload via ticket" on storage.objects;
create policy "checkin upload via ticket" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'checkins' and public.has_upload_ticket(name));
