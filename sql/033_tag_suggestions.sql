-- 조건 태그 DB화: 유저 제안 → 관리자 승인 → 배포 없이 사이트에 즉시 반영
-- (카테고리 제안(029)과 동일한 구조)

-- (1) 조건 태그 테이블 + 기존 9개 시드
create table condition_tags (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{1,20}$'),
  label text not null,
  sort_order int not null default 100,
  created_at timestamptz not null default now()
);
alter table condition_tags enable row level security;
create policy "condtags_read" on condition_tags for select using (true);

insert into condition_tags (key, label, sort_order) values
  ('night', '🌙 Night', 1),
  ('day', '☀️ Day', 2),
  ('rain', '🌧 Rain', 3),
  ('heavy_rain', '⛈ Heavy rain', 4),
  ('snow', '❄️ Snow', 5),
  ('heavy_snow', '🌨 Heavy snow', 6),
  ('accident', '💥 Accident', 7),
  ('fire', '🔥 Fire', 8),
  ('violence', '🥊 Violence', 9);

-- (2) set_stream_tags: 하드코딩 화이트리스트 대신 condition_tags 테이블로 검증
create or replace function set_stream_tags(p_video_id text, p_tags text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'login required';
  end if;
  update streams set tags = (
    select coalesce(array_agg(distinct t), '{}')
    from unnest(p_tags) t
    where t in (select key from condition_tags)
  )
  where video_id = p_video_id and content_type = 'video';
end;
$$;

-- (3) 태그 제안 테이블
create table tag_suggestions (
  id bigint generated always as identity primary key,
  suggestion text not null check (char_length(suggestion) between 2 and 40),
  suggested_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);
alter table tag_suggestions enable row level security;
create policy "tagsug_read" on tag_suggestions for select using (true);
create policy "tagsug_insert" on tag_suggestions for insert to authenticated
  with check (auth.uid() = suggested_by);
create policy "tagsug_admin_update"
  on tag_suggestions for update to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin));

-- (4) 승인: 조건 태그를 실제로 생성 (라벨은 제안 문구 그대로, 필요하면 SQL로 다듬기)
create or replace function approve_tag_suggestion(p_id bigint, p_key text, p_label text, p_sort int)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin) then
    raise exception 'admin only';
  end if;
  insert into condition_tags (key, label, sort_order)
  values (p_key, p_label, p_sort)
  on conflict (key) do nothing;
  update tag_suggestions set status = 'approved' where id = p_id;
end;
$$;
grant execute on function approve_tag_suggestion(bigint, text, text, int) to authenticated;
