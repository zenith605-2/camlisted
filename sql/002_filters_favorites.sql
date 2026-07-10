-- 3단계: 필터/기록화/즐겨찾기 확장. Supabase SQL Editor에서 1회 실행하세요.
-- (sql/schema.sql은 이미 적용되어 있으므로 다시 실행하지 않아도 됩니다.)

alter table streams add column status text not null default 'live' check (status in ('live', 'offline'));
alter table streams add column country text;
alter table streams add column category text;
alter table streams add column max_quality text;
alter table streams add column started_at timestamptz;

create table favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  video_id text not null references streams(video_id) on delete cascade,
  note text,
  created_at timestamptz not null default now(),
  primary key (user_id, video_id)
);

alter table favorites enable row level security;

create policy "favorites_owner_all"
  on favorites for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 유튜브 공식 IFrame Player API가 재생 중 보고하는 화질(getAvailableQualityLevels)을 누적 기록.
-- 좁은 기능(문자열 하나 검증 후 반영)이라 비로그인 방문자(anon)도 호출 가능.
create or replace function report_stream_quality(p_video_id text, p_quality text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  rank_new int;
  rank_old int;
  quality_rank constant jsonb := '{"hd2160":8,"hd1440":7,"hd1080":6,"hd720":5,"large":4,"medium":3,"small":2,"tiny":1}'::jsonb;
begin
  rank_new := coalesce((quality_rank->>p_quality)::int, 0);
  if rank_new = 0 then
    return;
  end if;
  select coalesce((quality_rank->>max_quality)::int, 0) into rank_old from streams where video_id = p_video_id;
  if rank_old is null or rank_new > rank_old then
    update streams set max_quality = p_quality where video_id = p_video_id;
  end if;
end;
$$;

grant execute on function report_stream_quality(text, text) to anon, authenticated;

-- 로그인 유저가 자동 분류된 카테고리를 직접 수정할 수 있게 하는 RPC
create or replace function set_stream_category(p_video_id text, p_category text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update streams set category = p_category where video_id = p_video_id;
end;
$$;

grant execute on function set_stream_category(text, text) to authenticated;
