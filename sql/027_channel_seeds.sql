-- 수동으로 등록하는 스캔 시드 채널 (예: 관리자의 유튜브 구독 채널 목록).
-- update.mjs가 매일 이 채널들을 스캔 대상에 합류시켜, 남는 검색 예산으로
-- 채널의 라이브 영상들을 수집한다 (결과는 승인 대기로 들어옴).
create table channel_seeds (
  channel_id text primary key,
  note text,
  added_at timestamptz not null default now()
);

alter table channel_seeds enable row level security;
-- 읽기/쓰기 모두 service role 전용 (정책 없음)
