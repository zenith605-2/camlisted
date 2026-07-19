-- 승인 카탈로그 재검수(ai_review.mjs auditApproved)가 쓰레기로 판정한 영상은 삭제 대신
-- visibility='hidden'으로 내린다. AI Review Log의 "Keep(복구)"는 지금 approval_status만
-- approved로 돌려서, 이렇게 숨겨진 항목은 복구해도 계속 안 보였다. restore가 visibility도
-- 'listed'로 되돌리도록 갱신한다 (047 정의 대체 — delete 분기는 동일하게 차단목록 등록 유지).
create or replace function resolve_ai_rejection(p_video_id text, p_action text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin) then
    raise exception 'admin only';
  end if;
  if p_action = 'delete' then
    -- 재수집 방지: 차단목록에 먼저 등록(이미 있으면 무시)
    insert into blocklist (video_id, blocked_by)
    values (p_video_id, auth.uid())
    on conflict (video_id) do nothing;
    delete from streams where video_id = p_video_id;
    update ai_review_log set resolution = 'deleted' where video_id = p_video_id and resolution = 'pending';
  elsif p_action = 'restore' then
    -- 되살리기 = 승인 + 공개 복구 (AI가 잘못 거절/숨김한 경우)
    update streams set approval_status = 'approved', visibility = 'listed' where video_id = p_video_id;
    update ai_review_log set resolution = 'restored' where video_id = p_video_id and resolution = 'pending';
  else
    raise exception 'invalid action';
  end if;
end;
$$;
grant execute on function resolve_ai_rejection(text, text) to authenticated;
