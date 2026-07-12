-- 카테고리 출처 추적 + AI 분류 체크 기록
-- category_source: 'keyword'(제목 키워드 매칭) / 'ai'(CLIP 썸네일 분류) / 'user'(유저가 직접 수정)
-- AI 재분류가 유저가 직접 고친 카테고리를 절대 덮어쓰지 않게 하기 위한 장치.
alter table streams add column category_source text check (category_source in ('keyword', 'ai', 'user'));

-- AI 분류를 이미 시도한 행 기록 (매일 같은 행을 다시 분류하지 않도록)
alter table streams add column ai_checked_at timestamptz;

-- 기존 자동 분류분은 전부 keyword 출처로 표시 (유저 수정분은 구분할 방법이 없어 일괄 keyword 처리 —
-- 이후부터는 유저가 수정하면 'user'로 기록되어 보호됨)
update streams set category_source = 'keyword' where category is not null;

-- 유저가 카드에서 카테고리를 바꾸면 출처를 'user'로 기록해 AI가 건드리지 못하게 한다
create or replace function set_stream_category(p_video_id text, p_category text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update streams set category = p_category, category_source = 'user' where video_id = p_video_id;
end;
$$;
