-- 하루 제보 개수 제한 기능을 도입 검토했다가 철회함(제한 없이 자유롭게 제보 가능하게 유지하기로 결정).
-- 트리거가 실제로 걸리지 않는 것으로 확인됐지만(원인 불명), 혹시 일부만 적용됐을 가능성에 대비해 정리한다.
drop trigger if exists enforce_submission_rate_limit_trigger on streams;
drop function if exists enforce_submission_rate_limit();
