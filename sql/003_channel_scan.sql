-- 채널 단위로 라이브를 그룹핑하고, 채널당 전체 라이브 스캔을 1회만 수행하기 위한 추가 컬럼/테이블
alter table streams add column channel_id text;

create table scanned_channels (
  channel_id text primary key,
  scanned_at timestamptz not null default now()
);
