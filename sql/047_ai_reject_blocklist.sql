-- AI Review Log의 "Confirm delete"가 삭제만 하면, 다음날 키워드 검색이 같은 영상을
-- 다시 신규로 수집해 pending으로 재등록하고 AI가 또 검수(쿼터 낭비)하게 된다.
-- 그래서 삭제와 동시에 blocklist에 등록해 영구 재수집을 막도록 갱신한다 (040 정의 대체).
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
    -- 되살리기 = 승인 상태로 공개 (AI가 잘못 거절한 경우)
    update streams set approval_status = 'approved' where video_id = p_video_id;
    update ai_review_log set resolution = 'restored' where video_id = p_video_id and resolution = 'pending';
  else
    raise exception 'invalid action';
  end if;
end;
$$;
grant execute on function resolve_ai_rejection(text, text) to authenticated;
