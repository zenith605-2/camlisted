-- 041: Crowd 카테고리 폐지 + 'Avenue(대로)' 신설
--
-- 배경: Crowd(군중)가 downtown(거리)과 키워드가 겹쳐(거리/보행자/city) 번화가 캠이
--   두 카테고리에 동시에 걸렸다. 게다가 '붐빔'은 장소 유형이 아니라 상태라
--   카테고리로 부적절했다. 대신 '차 비중'이라는 하나의 축으로 거리 계열을 정리한다:
--
--     🚦 Traffic  = 차도만        (고속도로·간선도로·터널)
--     🛣️ Avenue   = 차도 + 인도   (시내 대로·교차로·도로변)   ← 신설
--     🏙️ Street   = 인도 위주      (보행 상점가·골목·번화가 거리)
--
-- Supabase SQL Editor에서 1회 실행하세요.
-- (이전 설계에서 'quiet' 카테고리를 이미 만들었더라도 아래에서 안전하게 정리됩니다.)

-- (1) crowd 영상은 보행자 중심이므로 Street(downtown)로 이관 후 카테고리 삭제
update streams set category = 'downtown' where category = 'crowd';
delete from categories where key = 'crowd';

-- (1-b) 폐기된 'quiet' 카테고리 잔재 정리 (avenue로 대체됨)
update streams set category = 'downtown' where category = 'quiet';
delete from categories where key = 'quiet';

-- (2) Avenue 카테고리 추가
--   keywords는 (a) 제목 자동분류, (b) '부족 카테고리 부스트 검색'의 검색어로 이중 사용된다.
--   부스트 검색은 영문 키워드에 'cam'을 붙여 "avenue cam", "intersection cam" 등으로
--   유튜브에서 차도+인도가 함께 잡히는 도시 거리 캠을 찾아온다.
insert into categories (key, keywords, label_en, label_ko, label_ja, label_zh, label_es, sort_order, icon) values
  ('avenue',
   array['avenue','boulevard','대로','도로변','큰길','main street','main road',
         'intersection','crossing','crosswalk','교차로','횡단보도',
         '交差点','横断歩道','スクランブル','大通り','路口'],
   'Avenue', '대로', '大通り', '大道', 'Avenida', 38, '🛣️');

-- (3) 기존 영상 중 '교차로/횡단보도/대로'가 확실한 캠을 Avenue로 재분류해 초기 채움
--   (유저가 손수 지정한 분류 category_source='user'는 존중해서 건드리지 않는다)
update streams set category = 'avenue', category_source = 'keyword'
where category in ('traffic', 'downtown')
  and coalesce(category_source, '') <> 'user'
  and title ~* 'intersection|crossing|crosswalk|scramble|交差点|横断歩道|スクランブル|大通り|교차로|횡단보도|대로|avenue|boulevard';
