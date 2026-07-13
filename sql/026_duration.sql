-- 일반 영상(content_type='video')의 재생 길이(초) — 카드 썸네일에 길이 배지로 표시
-- update.mjs가 매일 생존확인 때 YouTube API contentDetails.duration에서 채워넣는다
alter table streams add column duration_seconds int;
