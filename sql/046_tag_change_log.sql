-- 조건 태그 변경 이력 로그 (카테고리 변경 로그 category_changes와 동일 패턴).
-- User Management에서 유저별 "조건 수정 횟수"를 집계하기 위해 추가.
-- 주의: 로그는 이 마이그레이션 실행 이후의 변경부터 쌓인다(과거 변경은 소급 집계 불가).
create table if not exists tag_changes (
  id bigint generated always as identity primary key,
  video_id text not null,
  old_tags text[],
  new_tags text[],
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);
alter table tag_changes enable row level security;
create policy "tag_changes_admin_read"
  on tag_changes for select to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and is_admin));

-- set_stream_tags가 변경 시 로그를 남기도록 갱신 (기존 032 정의를 대체).
create or replace function set_stream_tags(p_video_id text, p_tags text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old text[];
  v_new text[];
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  select tags into v_old from streams where video_id = p_video_id and content_type = 'video';
  if not found then return; end if;
  select coalesce(array_agg(distinct t order by t), '{}') into v_new
  from unnest(p_tags) t
  where t in ('night', 'day', 'rain', 'heavy_rain', 'snow', 'heavy_snow', 'accident', 'fire', 'violence');
  update streams set tags = v_new where video_id = p_video_id and content_type = 'video';
  -- 실제로 값이 바뀐 경우에만 로그를 남긴다(동일하면 기록하지 않음).
  if v_old is distinct from v_new then
    insert into tag_changes (video_id, old_tags, new_tags, changed_by)
    values (p_video_id, v_old, v_new, auth.uid());
  end if;
end;
$$;
grant execute on function set_stream_tags(text, text[]) to authenticated;
