-- 저두잇 초기 스키마 (설계수정안 v2 기준)
-- 시간 계산은 모두 KST(Asia/Seoul) 날짜 기준

create extension if not exists pgcrypto;

-- KST 날짜 계산
create or replace function public.kst_date(ts timestamptz)
returns date language sql immutable as $$
  select (ts at time zone 'Asia/Seoul')::date
$$;

-- 혼동 문자(I, L, O, 0, 1)를 뺀 8자리 초대 코드
create or replace function public.gen_invite_code()
returns text language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea := gen_random_bytes(8);
  code text := '';
begin
  for i in 0..7 loop
    code := code || substr(alphabet, (get_byte(bytes, i) % length(alphabet)) + 1, 1);
  end loop;
  return code;
end $$;

-- 개인 체험 기록: 사용자+초안 ID 유일 제약으로 새로고침 중복 저장 방지
create table public.personal_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  draft_id uuid not null,
  mission text not null check (mission in ('water', 'tidy', 'reading', 'walking')),
  completed boolean not null default false,
  completed_at timestamptz,          -- 체험 완료 시각 (챌린지 날짜에 사용하지 않음)
  memo text,
  next_action text,
  saved_at timestamptz not null default now(),  -- 서버 저장 시각
  unique (user_id, draft_id)
);

create type public.room_status as enum ('recruiting', 'scheduled', 'active', 'finished', 'cancelled', 'expired');

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id),
  invite_code text not null unique default public.gen_invite_code(),
  status public.room_status not null default 'recruiting',
  created_at timestamptz not null default now(),
  recruit_expires_at timestamptz not null default now() + interval '24 hours',
  starts_at timestamptz,             -- 확정 다음 날 00:00 KST
  ends_at timestamptz,               -- starts_at + 3일
  n0 int,                            -- 시작 인원
  goal int,                          -- 공동 목표 G
  earned int not null default 0,     -- 누적 획득 보상 H
  left_earned int not null default 0,-- 이탈자 획득 보상 L
  goal_reached_at timestamptz
);

create type public.member_status as enum ('joined', 'left', 'deleted');

create table public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  nickname text not null check (char_length(nickname) between 2 and 10),
  nickname_no int not null default 1,     -- 동명 닉네임 구분 번호
  status public.member_status not null default 'joined',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (room_id, nickname, nickname_no)
);
create unique index room_members_user_once on public.room_members (room_id, user_id) where user_id is not null;

-- 날짜별 인증 슬롯: 방·사용자·KST 날짜로 구분, 슬롯당 보상 1회
create table public.checkin_slots (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  slot_date date not null,
  valid boolean not null default true,     -- 현재 유효 인증 (C 집계)
  rewarded boolean not null default false, -- 보상 지급 여부 (취소·복구 시 중복 방지)
  photo_path text,
  memo text,
  checked_at timestamptz not null default now(),
  primary key (room_id, user_id, slot_date)
);

-- 서버 발급 업로드 경로: 사용자·방·날짜별 최대 3회, 5분 또는 당일 자정 중 빠른 시각 만료
create table public.upload_tickets (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  slot_date date not null,
  path text not null unique,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used boolean not null default false
);

create table public.deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('account', 'record')),
  target_id text,
  requested_at timestamptz not null default now(),
  due_at timestamptz not null default now() + interval '7 days',
  done_at timestamptz
);

-- RLS: 앱은 테이블에 직접 쓰지 않고 DB 함수를 통해서만 변경
alter table public.personal_records enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.checkin_slots enable row level security;
alter table public.upload_tickets enable row level security;
alter table public.deletion_requests enable row level security;

create or replace function public.is_active_member(r uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from room_members m
                 where m.room_id = r and m.user_id = auth.uid() and m.status = 'joined')
$$;

create policy "own records" on public.personal_records
  for select using (user_id = auth.uid());
create policy "members read room" on public.rooms
  for select using (public.is_active_member(id));
create policy "members read members" on public.room_members
  for select using (public.is_active_member(room_id));
create policy "members read checkins" on public.checkin_slots
  for select using (public.is_active_member(room_id) or user_id = auth.uid());
create policy "own deletion requests" on public.deletion_requests
  for select using (user_id = auth.uid());
