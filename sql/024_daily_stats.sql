-- 일일 운영 집계: update.mjs가 매일 실행 끝에 그날의 결과를 기록한다 (관리자 대시보드용)
create table daily_stats (
  stat_date date primary key,
  existing_count int not null default 0,   -- 갱신 시작 시점의 기존 영상 수
  valid_count int not null default 0,      -- 생존 확인을 통과한(유효) 영상 수
  offline_count int not null default 0,    -- 오프라인 상태로 판정된 수
  new_count int not null default 0,        -- 이번 실행에서 새로 추가된 수
  deleted_count int not null default 0,    -- 이번 실행에서 삭제된 수(오탐+임시등록 만료+오프라인 만료)
  created_at timestamptz not null default now()
);

alter table daily_stats enable row level security;

-- 집계 숫자는 민감정보가 아니므로 읽기는 공개 (쓰기는 service role만 - insert 정책 없음)
create policy "daily_stats_public_read"
  on daily_stats for select
  using (true);

-- 날짜별 방문자 수 (visit_log는 RLS로 직접 조회가 막혀 있어 view로 집계만 노출)
create view daily_visit_counts as
  select visit_date, count(*)::int as visitors
  from visit_log
  group by visit_date;
grant select on daily_visit_counts to anon, authenticated;

-- 날짜별 신규 가입자 수
create view daily_signup_counts as
  select created_at::date as signup_date, count(*)::int as signups
  from profiles
  group by created_at::date;
grant select on daily_signup_counts to anon, authenticated;
