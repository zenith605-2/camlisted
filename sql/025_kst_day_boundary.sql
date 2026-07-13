-- "오늘"의 기준을 UTC 자정(= 한국시간 오전 9시)에서 한국(KST) 자정으로 통일한다.
-- visit_log의 visit_date는 이제 클라이언트가 KST 날짜로 넣으므로, "오늘" 비교도 KST로.

create or replace view visit_stats as
select
  (select count(*) from visit_log where visit_date = (now() at time zone 'Asia/Seoul')::date) as today_count,
  (select count(distinct visitor_key) from visit_log) as total_count;

-- 가입자 일별 집계도 KST 날짜 기준으로
create or replace view daily_signup_counts as
  select (created_at at time zone 'Asia/Seoul')::date as signup_date, count(*)::int as signups
  from profiles
  group by 1;
