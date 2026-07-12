-- 관리자가 채널 하나를 통째로(그 채널 소속 영상 전체를) 일괄삭제한 경우,
-- 그 채널 자체를 차단해 다음날 검색/채널스캔이 같은 채널에서 또 영상을 끌어오지 못하게 한다.
create table blocked_channels (
  channel_id text primary key,
  blocked_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table blocked_channels enable row level security;

create policy "blocked_channels_admin_all"
  on blocked_channels for all
  to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

create policy "blocked_channels_public_read"
  on blocked_channels for select
  using (true);
