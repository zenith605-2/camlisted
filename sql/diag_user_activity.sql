-- 진단용(스키마 변경 없음). 특정 이용자가 사이트에서 실제로 뭘 했는지 전부 뽑는다.
-- 이메일만 바꿔서 Supabase SQL Editor에서 실행. 쿼리가 4개이므로 하나씩 실행해야 결과가 다 보인다.

-- (1) 조건 태그 변경 내역 — 어떤 영상의 태그를 뭐에서 뭐로 바꿨는지 (최신순)
select c.changed_at, c.video_id, s.title, c.old_tags, c.new_tags
from tag_changes c
left join streams s on s.video_id = c.video_id
where c.changed_by = (select id from auth.users where email = 'akaka9887@gmail.com')
order by c.changed_at desc
limit 50;

-- (2) 카테고리 변경 내역
select c.changed_at, c.video_id, s.title, c.old_category, c.new_category
from category_changes c
left join streams s on s.video_id = c.video_id
where c.changed_by = (select id from auth.users where email = 'akaka9887@gmail.com')
order by c.changed_at desc
limit 50;

-- (3) 링크 제보 내역
select created_at, video_id, title, status
from submission_log
where user_id = (select id from auth.users where email = 'akaka9887@gmail.com')
order by created_at desc;

-- (4) 계정 기본 정보 — 언제 가입했고 마지막 접속이 언제인지
select email, created_at as joined, last_sign_in_at
from auth.users
where email = 'akaka9887@gmail.com';
