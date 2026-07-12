-- 유저 건의/개선요청 게시판
create table feedback_posts (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  title text not null check (char_length(title) between 1 and 100),
  content text not null check (char_length(content) between 1 and 1000),
  status text not null default 'open' check (status in ('open', 'planned', 'done', 'declined')),
  upvote_count int not null default 0,
  created_at timestamptz not null default now()
);

alter table feedback_posts enable row level security;

create policy "feedback_posts_public_read"
  on feedback_posts for select
  using (true);

create policy "feedback_posts_user_insert"
  on feedback_posts for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "feedback_posts_admin_update"
  on feedback_posts for update
  to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

create policy "feedback_posts_owner_or_admin_delete"
  on feedback_posts for delete
  to authenticated
  using (auth.uid() = user_id or exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

create table feedback_upvotes (
  post_id bigint not null references feedback_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table feedback_upvotes enable row level security;

create policy "feedback_upvotes_insert"
  on feedback_upvotes for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "feedback_upvotes_public_read"
  on feedback_upvotes for select
  using (true);

create or replace function handle_new_feedback_upvote()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update feedback_posts set upvote_count = upvote_count + 1 where id = new.post_id;
  return new;
end;
$$;

create trigger on_feedback_upvote_insert
after insert on feedback_upvotes
for each row execute function handle_new_feedback_upvote();
