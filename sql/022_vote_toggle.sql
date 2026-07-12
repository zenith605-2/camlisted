-- 추천/비추천을 토글(취소) 가능하게 만든다. 본인 투표 조회/삭제 권한 추가 + 삭제 시 카운트 감소 트리거.
create policy "upvotes_owner_select"
  on upvotes for select
  to authenticated
  using (auth.uid() = user_id);

create policy "upvotes_owner_delete"
  on upvotes for delete
  to authenticated
  using (auth.uid() = user_id);

create policy "downvotes_owner_select"
  on downvotes for select
  to authenticated
  using (auth.uid() = user_id);

create policy "downvotes_owner_delete"
  on downvotes for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace function handle_upvote_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update streams set upvote_count = greatest(0, upvote_count - 1) where video_id = old.video_id;
  return old;
end;
$$;

create trigger on_upvote_delete
after delete on upvotes
for each row execute function handle_upvote_delete();

create or replace function handle_downvote_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update streams set downvote_count = greatest(0, downvote_count - 1) where video_id = old.video_id;
  return old;
end;
$$;

create trigger on_downvote_delete
after delete on downvotes
for each row execute function handle_downvote_delete();
