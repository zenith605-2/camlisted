-- 유저가 본인 닉네임(display_name)만 직접 수정할 수 있게 허용.
-- is_admin/bonus_credits 등 다른 컬럼은 컬럼 단위 grant로 막아 RLS만으로는 뚫리지 않게 한다.
create policy "profiles_owner_update"
  on profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

revoke update on profiles from authenticated;
grant update (display_name) on profiles to authenticated;
