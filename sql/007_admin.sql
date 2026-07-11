-- 관리자 권한 + streams 테이블 수정/삭제 권한 부여
alter table profiles add column is_admin boolean not null default false;

create policy "streams_admin_update"
  on streams for update
  to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

create policy "streams_admin_delete"
  on streams for delete
  to authenticated
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

-- 본인 계정을 관리자로 지정하려면 아래를 이메일만 바꿔서 실행하세요:
-- update profiles set is_admin = true
--   where id = (select id from auth.users where email = 'YOUR_GOOGLE_EMAIL@gmail.com');
