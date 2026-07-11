-- 추천/비추천 품질 신호. 비추 10개 이상 -> 삭제하지 않고 visibility='hidden'으로 숨김 (별도 카테고리로 조회 가능)
alter table streams add column downvote_count int not null default 0;
alter table streams add column visibility text not null default 'listed' check (visibility in ('listed', 'hidden'));

create table downvotes (
  video_id text not null references streams(video_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

alter table downvotes enable row level security;

create policy "downvotes_user_insert"
  on downvotes for insert
  to authenticated
  with check (auth.uid() = user_id);

create or replace function handle_new_downvote()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update streams set downvote_count = downvote_count + 1 where video_id = new.video_id;
  update streams set visibility = 'hidden' where video_id = new.video_id and downvote_count >= 10;
  return new;
end;
$$;

create trigger on_downvote_insert
after insert on downvotes
for each row execute function handle_new_downvote();
