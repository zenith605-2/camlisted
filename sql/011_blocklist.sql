-- 관리자가 삭제한 videoId를 영구 차단 목록에 기록해, 다음날 자동 검색/채널스캔이
-- 같은 영상을 "신규"로 착각해 다시 넣지 못하게 한다.
create table blocklist (
  video_id text primary key,
  blocked_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table blocklist enable row level security;

create policy "blocklist_admin_all"
  on blocklist for all
  to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

-- 제보 폼에서 "이미 관리자가 삭제한 영상인지" 확인할 수 있게 조회는 누구나 허용 (내용 자체는 민감하지 않음)
create policy "blocklist_public_read"
  on blocklist for select
  using (true);
