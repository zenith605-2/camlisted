-- 카테고리별 아이콘: 사이드바/필터/카드에 라벨 앞에 붙여서 표시
-- 새로 승인되는 카테고리는 기본 📍를 받고, 필요하면 update 한 줄로 바꾼다:
--   update categories set icon = '🌫' where key = 'fog';
alter table categories add column icon text not null default '📍';

update categories set icon = v.icon
from (values
  ('beach', '🏖️'),
  ('parking', '🅿️'),
  ('traffic', '🚦'),
  ('harbor', '⚓'),
  ('airport', '✈️'),
  ('train', '🚆'),
  ('river', '🏞️'),
  ('mountain', '⛰️'),
  ('downtown', '🏙️'),
  ('plaza', '⛲'),
  ('park', '🌳'),
  ('alley', '🏘️'),
  ('skyline', '🌆'),
  ('dashcam', '🚗'),
  ('wildlife', '🦌'),
  ('crowd', '🚶'),
  ('indoor', '🏢'),
  ('construction', '🏗️'),
  ('walk', '👣'),
  ('aerial', '🚁'),
  ('other', '📁')
) as v(key, icon)
where categories.key = v.key;
