-- 045: 임베드 차단 영상을 삭제 대신 표시 전환
--
-- 지금까지는 embeddable=false(외부 사이트 재생 차단)인 영상을 매일 삭제했다.
-- 이제는 남겨두고 카드에 '외부재생불가' 배지를 붙여 썸네일로 보여주며,
-- 클릭 시 유튜브 새 탭으로 연다. 밤 갱신이 이 플래그를 매일 최신으로 유지한다.
--
-- Supabase SQL Editor에서 1회 실행하세요.

alter table streams add column embeddable boolean not null default true;
