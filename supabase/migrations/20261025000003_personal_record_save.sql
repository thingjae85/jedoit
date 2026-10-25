-- 앱의 미션 ID와 기록 ID 형식에 맞추고, 개인 기록 저장·삭제 함수를 추가한다.

alter table public.personal_records drop constraint if exists personal_records_mission_check;
alter table public.personal_records
  add constraint personal_records_mission_check check (mission in ('water', 'cleanup', 'reading', 'walking'));
alter table public.personal_records alter column draft_id type text using draft_id::text;

-- 같은 초안을 다시 보내도 한 번만 저장된다 (사용자+초안 ID 유일 제약)
create or replace function public.save_personal_record(
  p_draft_id text, p_mission text, p_completed_at timestamptz, p_memo text, p_next_action text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into personal_records (user_id, draft_id, mission, completed, completed_at, memo, next_action)
  values (auth.uid(), p_draft_id, p_mission, true, p_completed_at, left(p_memo, 200), p_next_action)
  on conflict (user_id, draft_id) do nothing;
end $$;

create policy "own records delete" on public.personal_records
  for delete using (user_id = auth.uid());
