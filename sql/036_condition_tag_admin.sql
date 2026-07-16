-- 조건 태그 관리자 편집/삭제 RPC (계정 페이지의 태그 관리 섹션에서 사용)

-- 라벨(이모지 포함) 수정
create or replace function update_condition_tag(p_key text, p_label text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin) then
    raise exception 'admin only';
  end if;
  update condition_tags set label = p_label where key = p_key;
end;
$$;
grant execute on function update_condition_tag(text, text) to authenticated;

-- 삭제: 태그 자체와 함께, 영상들에 이미 달린 해당 태그도 모두 제거
create or replace function delete_condition_tag(p_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin) then
    raise exception 'admin only';
  end if;
  delete from condition_tags where key = p_key;
  update streams set tags = array_remove(tags, p_key) where p_key = any(tags);
end;
$$;
grant execute on function delete_condition_tag(text) to authenticated;
