-- 운영자 본인 IP의 방문 기록을 통계에서 제거한다.
-- daily_visit_counts / visit_stats / (소스·국가·재방문 집계)는 모두 visit_log 위의 뷰/집계라,
-- 이 행들을 지우면 과거 방문수까지 전부 자동으로 재계산돼 깨끗해진다.
-- 앞으로의 방문은 app.js의 EXCLUDED_VISIT_IPS가 애초에 기록하지 않는다(IP 바뀌면 양쪽에 추가).

-- (1) 먼저 그 IP 방문자의 체류시간 기록을 정리 (visit_durations엔 ip가 없어 visitor_key로 매칭)
delete from visit_durations where visitor_key in (
  select visitor_key from visit_log where ip in ('39.118.165.152')
);

-- (2) 그다음 방문 기록 자체를 삭제 → 위의 뷰들이 자동으로 재계산됨
delete from visit_log where ip in ('39.118.165.152');
