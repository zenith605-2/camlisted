-- 구글봇(66.249.64.0/19 대역)이 JS를 실행하며 렌더링마다 새 방문자로 기록돼
-- 방문자 통계가 부풀려졌다 (2026-07-21 하루에만 100회+).
-- 앞으로는 app.js의 IS_BOT(UA 검사)이 기록 자체를 막고, 이미 쌓인 행은 여기서 지운다.
-- 크롤러 방문은 통계적 의미가 없으므로 흔한 봇 대역/패턴을 함께 정리한다.

-- (1) 해당 방문자키의 체류시간 기록 먼저 정리
delete from visit_durations where visitor_key in (
  select visitor_key from visit_log where ip like '66.249.%'
);

-- (2) 구글봇 대역 방문 기록 삭제 → daily_visit_counts/visit_stats 뷰가 자동 재계산됨
delete from visit_log where ip like '66.249.%';
