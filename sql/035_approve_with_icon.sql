-- 카테고리 제안 승인 시 아이콘까지 한 번에 받도록 RPC 확장
-- (이전 4-인자 버전은 삭제 — 남겨두면 PostgREST가 어느 쪽을 부를지 모호해짐)
drop function if exists approve_category_suggestion(bigint, text, text, int);

create or replace function approve_category_suggestion(p_id bigint, p_key text, p_label text, p_sort int, p_icon text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin) then
    raise exception 'admin only';
  end if;
  insert into categories (key, keywords, label_en, label_ko, label_ja, label_zh, label_es, sort_order, icon)
  values (p_key, array[lower(p_label)], p_label, p_label, p_label, p_label, p_label, p_sort,
          coalesce(nullif(trim(p_icon), ''), '📍'))
  on conflict (key) do nothing;
  update category_suggestions set status = 'approved' where id = p_id;
end;
$$;
grant execute on function approve_category_suggestion(bigint, text, text, int, text) to authenticated;
