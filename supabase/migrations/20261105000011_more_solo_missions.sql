-- 혼자 하기 미션이 늘어나고(오늘의 발견, 내가 만든 미션) 미션 id 목록을 고정할 수 없게 됐다.
-- 미션 이름 목록 대신 길이만 확인한다. 사진은 서버에 올리지 않는다.
alter table public.personal_records drop constraint if exists personal_records_mission_check;
alter table public.personal_records
  add constraint personal_records_mission_check check (char_length(mission) between 1 and 60);
