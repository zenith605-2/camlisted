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
  ['wyfL7lGC0N4', 'live'],   // Bird Feeder & Wildlife Camera Scotland UK
  ['RnCAl0mQgqA', 'live'],   // Birds in the Forest 24/7 LIVE - Morten Hilmer
  ['XYsQXRLUfsE', 'video'],  // Dashcam Compilation - Truck Moments 2026
  ['TDIOcFrKuto', 'video'],  // Exposed: UK Dash Cams Compilation
  ['jJXT2zGlSc0', 'video'],  // Best of Car Crashes 2026 (dashcam)
  ['JQ_jwk_7OVE', 'live'],   // EarthCam Live: Times Square North 4K
  ['z-jYdOIKcTQ', 'live'],   // EarthCam Live: Times Square Crossroads
  ['dfVK7ld38Ys', 'live'],   // Shibuya Scramble Crossing Live Cam (FNN)
  ['UTIRF2g_8Ic', 'live'],   // Shibuya City Scramble Crossing Live Camera
  ['X7tdyNFpp1g', 'live'],   // Levi Ski Resort Village View - Finland
  ['RbPKkXif03U', 'live'],   // Finnish Ski Resorts Ruka and Pyhä Webcams
  ['sxgx5ZqAAxo', 'live'],   // Málaga Port Live Cam
];

function liveThumbnail(videoId) {
  return `https://i.ytimg.com/vi/${videoId}/hqdefault_live.jpg`;
}

async function main() {
  const rows = candidates.map(([videoId, contentType]) => ({
    video_id: videoId,
    source: 'keyword',
    matched_keyword: 'manual search',
    content_type: contentType,
    status: 'live',
    thumbnail: liveThumbnail(videoId),
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
