-- 방송 중지/영상 삭제로 offline 전환된 시점을 기록. 7일 넘게 계속 offline이면
-- update.mjs가 자동 삭제한다 (블록리스트에는 안 올림 - 나중에 복구되면 재검색으로 다시 들어올 수 있음).
alter table streams add column offline_since timestamptz;
