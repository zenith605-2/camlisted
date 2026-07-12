-- 닉네임 중복 방지 (대소문자 구분 없이). 닉네임을 아직 안 정한 계정(NULL)은 여러 개 허용.
create unique index profiles_display_name_unique_idx
  on profiles (lower(display_name))
  where display_name is not null;
