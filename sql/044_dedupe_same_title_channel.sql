-- 044: 같은 채널 + 완전 동일 제목의 "라이브" 중복 1회 정리 (즉시 실행용)
--
-- 같은 실시간 피드가 여러 스트림으로 잡힌 경우(예: Le Tréport 해변 라이브 2개)만
-- 최신 등록 1개를 남기고 정리한다. 일반 영상(video)은 제목이 같아도 다른 날짜의
-- 녹화본일 수 있으므로(예: 엘리시안강촌 일별 아카이브 8개) 절대 건드리지 않는다.
-- 앞으로는 매일 밤 update.mjs가 같은 정리를 자동으로 수행한다.
--
-- Supabase SQL Editor에서 1회 실행하세요.

with ranked as (
  select video_id,
         row_number() over (
           partition by channel_title, title
           order by added_at desc nulls last
         ) as rn
  from streams
  where content_type = 'live'
    and title is not null and channel_title is not null
),
doomed as (
  select video_id from ranked where rn > 1
),
del as (
  delete from streams where video_id in (select video_id from doomed)
  returning video_id
)
insert into blocklist (video_id)
select video_id from del
on conflict (video_id) do nothing;
