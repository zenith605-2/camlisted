-- 유저 제보 이력: 제보한 링크가 승인됐는지/거절됐는지를 유저 본인이 볼 수 있게 기록한다.
-- 지금은 거절(관리자 확정/AI 확정/7일 만료)되면 streams 행이 삭제돼 흔적이 없다.
-- 승인·삭제 경로가 여러 갈래(클라이언트/RPC/야간 스크립트)라 streams 트리거로 전부 잡는다.
create table submission_log (
  user_id uuid not null,
  video_id text not null,
  title text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reason text, -- 거절 시 AI 판정 이유(있으면)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, video_id)
);
alter table submission_log enable row level security;
-- 본인 것만 조회 (쓰기는 아래 security definer 트리거만 수행)
create policy "submission_log_own_read" on submission_log for select to authenticated
  using (auth.uid() = user_id);

-- (1) 제보 등록 시 이력 생성. 같은 영상을 재제보하면 pending으로 리셋.
create or replace function log_user_submission() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into submission_log (user_id, video_id, title, status)
  values (new.added_by, new.video_id, new.title,
          case when new.approval_status = 'approved' then 'approved' else 'pending' end)
  on conflict (user_id, video_id) do update
    set status = excluded.status, title = excluded.title, reason = null, updated_at = now();
  return new;
end; $$;
create trigger on_submission_insert after insert on streams
  for each row when (new.source = 'user' and new.added_by is not null)
  execute function log_user_submission();

-- (2) 제목이 채워지거나(야간 갱신) 승인되면 이력에 반영.
create or replace function sync_user_submission() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update submission_log set
    title = coalesce(new.title, title),
    status = case when new.approval_status = 'approved' then 'approved' else status end,
    updated_at = now()
  where user_id = new.added_by and video_id = new.video_id;
  return new;
end; $$;
create trigger on_submission_update after update on streams
  for each row when (new.source = 'user' and new.added_by is not null)
  execute function sync_user_submission();

-- (3) 승인 전에 삭제되면 = 거절. AI 판정 이유가 로그에 있으면 함께 남긴다.
--     (이미 approved였던 것의 삭제는 '거절'이 아니라 방송 종료 등 운영 정리이므로 상태 유지)
create or replace function close_user_submission() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update submission_log set
    status = 'rejected',
    reason = coalesce((select r.reason from ai_review_log r
                       where r.video_id = old.video_id
                       order by r.reviewed_at desc limit 1), reason),
    updated_at = now()
  where user_id = old.added_by and video_id = old.video_id and status = 'pending';
  return old;
end; $$;
create trigger on_submission_delete after delete on streams
  for each row when (old.source = 'user' and old.added_by is not null)
  execute function close_user_submission();

-- (4) 백필: 현재 살아있는 유저 제보를 이력에 채운다. (이미 삭제된 과거 제보는 복원 불가)
insert into submission_log (user_id, video_id, title, status, created_at)
select added_by, video_id, title,
       case when approval_status = 'approved' then 'approved' else 'pending' end,
       added_at
from streams
where source = 'user' and added_by is not null
on conflict (user_id, video_id) do nothing;
