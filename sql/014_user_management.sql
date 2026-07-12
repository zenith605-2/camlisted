-- 관리자가 다른 유저의 is_admin 여부를 안전하게 바꿀 수 있는 RPC.
-- profiles에 직접 update 권한/정책을 여는 대신(자기 자신을 관리자로 셀프 승격하는 구멍이 생길 수 있음),
-- 함수 안에서 "호출자가 이미 관리자인지"를 먼저 검증한 뒤에만 대상 유저를 갱신한다.
create or replace function set_user_admin(p_user_id uuid, p_is_admin boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and is_admin = true) then
    raise exception 'not_authorized';
  end if;
  update profiles set is_admin = p_is_admin where id = p_user_id;
end;
$$;

grant execute on function set_user_admin(uuid, boolean) to authenticated;
