-- 시드 채널의 일반 영상 스캔 기록: 채널당 1회만 일반 업로드 영상을 수집하기 위한 마커
alter table channel_seeds add column video_scanned_at timestamptz;
