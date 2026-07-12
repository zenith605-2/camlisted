-- 영상 재생 모달 아래에 다는 댓글
create table comments (
  id bigint generated always as identity primary key,
  video_id text not null references streams(video_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 500),
  created_at timestamptz not null default now()
);

alter table comments enable row level security;

create policy "comments_public_read"
  on comments for select
  using (true);

create policy "comments_user_insert"
  on comments for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "comments_owner_delete"
  on comments for delete
  to authenticated
  using (auth.uid() = user_id);

create policy "comments_admin_delete"
  on comments for delete
  to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));
