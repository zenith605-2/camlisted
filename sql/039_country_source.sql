-- 국가 분류 출처 추적: 'title'(제목 지명/언어) | 'channel'(채널 등록국) | 'user'(수동)
-- 매일 갱신 시 'user'가 아닌 행은 제목으로 재분류해 정확도를 높인다 (유저 수정은 보존).
alter table streams add column if not exists country_source text;

-- 기존 값이 있는 행은 일단 'channel'로 표시 (다음 실행에서 제목 재분류가 덮어씀)
update streams set country_source = 'channel' where country is not null and country_source is null;

-- 유저가 카드에서 국가를 바꾸면 출처를 'user'로 고정해 자동 분류가 못 덮게 한다
create or replace function set_stream_country(p_video_id text, p_country text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  if p_country is not null and p_country !~ '^[A-Z]{2}$' then
    raise exception 'invalid country code';
  end if;
  update streams set country = p_country, country_source = 'user' where video_id = p_video_id;
end;
$$;
grant execute on function set_stream_country(text, text) to authenticated;
