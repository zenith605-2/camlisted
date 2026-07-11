// 1회용: 웹 검색으로 직접 찾은 CCTV/영상 후보를 시드 삽입한다.
// 제목/채널명/카테고리 등은 비워두고, 다음날 update.mjs의 생존확인 루프가 채워넣고
// 유효하지 않은 것은 자동으로 걸러낸다 (유저 제보와 동일한 처리 경로).
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 환경변수가 필요합니다.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// [videoId, contentType] — YouTube 검색 결과에서 직접 확인한 후보
const candidates = [
  // 블랙박스/주행 (dashcam) - RR&BD Driving School, Dash Cam Owners Australia, UK Dash Cameras 채널 스캔 포함
  ['gdsn5C3Dki0', 'video'],  // Road Rager Tried to Start a Fight... Then Got Arrested!
  ['JTzk9HTofj0', 'video'],  // 테슬라 추월... 운전 실패 모음
  ['Wy7SPN44F4c', 'video'],  // Worst Drivers of March 2026 | Dashcam Fails
  ['DdN_NmZ_Upk', 'video'],  // Dash Cam Owners Australia Weekly Submissions July Week 1
  ['E4FnISFNdWk', 'video'],  // Dash Cam Owners Australia Crash Compilation 52
  ['pstThH5bETY', 'video'],  // 대시 캠 오너스 오스트레일리아 주간 제보 6월 4주차
  ['lDcPiwZUNTE', 'video'],  // UK Dash Cameras - Compilation 21 - 2026
  ['YHvU4TbNsTs', 'video'],  // 영국 블랙박스 모음 20 - 2026
  ['FanHTALmazY', 'video'],  // UK Dash Cameras - Compilation 19 - 2026
  // 야생동물 (wildlife) - Discover Wildlife, WILD NATURE 채널 스캔 포함
  ['mxucq6FrOA0', 'video'],  // YELLOWSTONE | Battles for Survival in the Most Extreme Winter
  ['qprNraWQZF4', 'video'],  // Win or Die (FULL EPISODE) | Deadliest Battles for Survival
  ['fKsrERSd_Lo', 'video'],  // WILD SAVANNAH | Survival Stories from the Heart of Africa
  ['Dg32Okyvaq0', 'video'],  // African Savannah (Full Episode)
  ['bCs9KJHJ9oo', 'video'],  // Botswana (Full Episode)
  ['mFNnaTw4sNc', 'video'],  // Wild Alaska | Survival in the Land of Ice and Apex Predators
  ['ary66lPQJC4', 'video'],  // WILD COLOMBIA | South America's Most Dangerous Predators
  ['x1FYpkNM1DE', 'video'],  // WILD KENYA | The War Between a Lion and a Troop of Baboons
  // 군중/보행자 (crowd) - World Wanderings, Prowalk Tours 등 4K 워킹투어 채널 스캔 포함
  ['28ZjrtD_iL0', 'video'],  // TOKYO WALKING TOUR - Streets of Japan Day & Night 4K
  ['6jrjkofvTgs', 'video'],  // NEW YORK Walk 4K - Busy Streets of Manhattan
  ['ca9uN3QyDmQ', 'video'],  // Seoul Nightlife Adventure - Street Markets & Party Districts
  ['3FUIYAwQ7Xs', 'video'],  // Tokyo Evening Walk in Shinjuku - 4K HDR 60fps
  ['e8f7NnyO4PA', 'video'],  // Shibuya Night Walk: Tokyo's Neon Wonderland
  ['91BeCFEr0pI', 'video'],  // Halifax Waterfront Walking Tour
  ['ILx5FXoAphQ', 'video'],  // The Best of Montréal in Summer - Downtown 4K Walk
  ['oqb6bgNytLo', 'video'],  // Walking Vancouver FIFA Host City in 4K
];

function thumbnailFor(videoId, contentType) {
  const variant = contentType === 'live' ? 'hqdefault_live' : 'hqdefault';
  return `https://i.ytimg.com/vi/${videoId}/${variant}.jpg`;
}

async function main() {
  const rows = candidates.map(([videoId, contentType]) => ({
    video_id: videoId,
    source: 'keyword',
    matched_keyword: 'manual search',
    content_type: contentType,
    status: 'live',
    thumbnail: thumbnailFor(videoId, contentType),
  }));

  const { data, error } = await supabase
    .from('streams')
    .upsert(rows, { onConflict: 'video_id', ignoreDuplicates: true })
    .select('video_id');

  if (error) {
    console.error('삽입 실패:', error.message);
    process.exit(1);
  }
  console.log(`시도 ${rows.length}건 중 신규 ${data.length}건 삽입 (나머지는 이미 존재해 건너뜀)`);
}

main();
