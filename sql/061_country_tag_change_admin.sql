-- 국가 변경 이력을 카테고리와 동일하게 남긴다 (지금까지는 국가만 전혀 기록이 안 남고 있었음).
-- 조건 태그는 이미 tag_changes에 기록되고 있지만(046) 관리자 화면에서 목록을 볼 방법이 없었다 —
-- 그건 SQL만으로 해결되는 게 아니라 account.js/html 쪽 화면이 필요해서 이 파일은 country_changes만 다룬다.

create table if not exists country_changes (
  id bigint generated always as identity primary key,
  video_id text not null,
  old_country text,
  new_country text,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);
alter table country_changes enable row level security;
create policy "country_changes_admin_read"
  on country_changes for select to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin));

-- set_stream_country 재정의: 055 정의에 로그 기록을 추가 (카테고리의 category_changes 패턴과 동일)
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
  insert into country_changes (video_id, old_country, new_country, changed_by)
    select video_id, country, p_country, auth.uid()
    from streams where video_id = p_video_id and country is distinct from p_country;
  update streams set country = p_country, country_source = 'user' where video_id = p_video_id;
end;
$$;
grant execute on function set_stream_country(text, text) to authenticated;
