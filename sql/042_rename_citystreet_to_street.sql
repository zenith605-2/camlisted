-- 042: 'City Street' 라벨 → 'Street'로 변경
--
-- 배경: 'City Street'은 번화가(downtown) 뉘앙스라 도로 캠까지 애매하게 걸렸다.
--       그냥 'Street(거리)'로 넓히면 "사람이 다니는 거리 전반"으로 읽혀서
--       Traffic(차도·도로)과의 대비가 선명해진다.
--
-- 주의: key는 'downtown' 그대로 유지한다. key를 바꾸면 기존 streams.category 값과
--       SEO 페이지 슬러그(c/downtown.html)가 모두 깨지므로, 사용자에게 보이는
--       라벨(label_*)만 교체한다.
--
-- Supabase SQL Editor에서 1회 실행하세요.

update categories set
  label_en = 'Street',
  label_ko = '거리',
  label_ja = '通り',
  label_zh = '街道',
  label_es = 'Calle'
where key = 'downtown';
