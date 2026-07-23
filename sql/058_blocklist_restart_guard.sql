-- 삭제한 라이브가 "재시작"으로 되돌아오는 루프 차단.
--
-- 배경: 모든 관리자 삭제는 video_id를 blocklist에 넣으므로 같은 영상은 다시 못 들어온다.
-- 그런데 라이브 스트림은 채널이 방송을 껐다 켜면 새 video_id를 받는다. 그러면 자정 검색이
-- "새 영상"으로 수집하고, 제미나이도 처음 보는 항목이라 다시 승인해 버린다 — 관리자가
-- 지운 카메라가 며칠 뒤 멀쩡히 돌아오는 이유가 이것이다.
--
-- 대책: 차단 시점에 채널ID와 제목을 함께 기록하고, 수집기(update.mjs)가
-- "차단된 (채널, 제목) 쌍과 일치하는 후보"를 검색 단계에서 걸러낸다.
-- 채널 전체를 막지 않는 이유: PixCams처럼 카메라 여러 대를 운영하는 채널에서
-- 한 대만 지웠을 때 나머지까지 막히면 안 되기 때문.

alter table blocklist add column if not exists channel_id text;
alter table blocklist add column if not exists title text;

-- AI 검수 로그의 "Confirm delete"(resolve_ai_rejection)도 채널·제목을 함께 기록하도록 갱신 (047 대체)
create or replace function resolve_ai_rejection(p_video_id text, p_action text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_channel text;
  v_title text;
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin) then
    raise exception 'admin only';
  end if;
  if p_action = 'delete' then
    select channel_id, title into v_channel, v_title from streams where video_id = p_video_id;
    insert into blocklist (video_id, blocked_by, channel_id, title)
    values (p_video_id, auth.uid(), v_channel, v_title)
    on conflict (video_id) do nothing;
    delete from streams where video_id = p_video_id;
    update ai_review_log set resolution = 'deleted' where video_id = p_video_id and resolution = 'pending';
  elsif p_action = 'restore' then
    update streams set approval_status = 'approved' where video_id = p_video_id;
    update ai_review_log set resolution = 'restored' where video_id = p_video_id and resolution = 'pending';
  else
    raise exception 'invalid action';
  end if;
end;
$$;
grant execute on function resolve_ai_rejection(text, text) to authenticated;

-- 확인용: 채널·제목이 채워진 차단 행 수 (이 마이그레이션 직후엔 0 — 앞으로의 삭제부터 기록됨)
select count(*) as rows_with_pair from blocklist where channel_id is not null and title is not null;
