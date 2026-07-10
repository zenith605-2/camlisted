// 매일 실행: 유튜브 라이브 중인 CCTV 스트림 목록을 갱신한다.
// 1) 기존 목록의 생존 여부 확인 (중지된 것 제거)
// 2) 키워드 검색으로 신규 라이브 CCTV 후보 탐색 및 검증 후 추가
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const STREAMS_PATH = path.join(ROOT, 'data', 'streams.json');
const KEYWORDS_PATH = path.join(ROOT, 'config', 'keywords.json');

const API_KEY = process.env.YOUTUBE_API_KEY;
const BASE = 'https://www.googleapis.com/youtube/v3';

if (!API_KEY) {
  console.error('환경변수 YOUTUBE_API_KEY 가 설정되어 있지 않습니다.');
  process.exit(1);
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`YouTube API error ${res.status}: ${text}`);
  }
  return res.json();
}

// videoIds 중 현재 실제로 라이브 중인 것만 videoId -> snippet 맵으로 반환
async function getLiveSnippets(videoIds) {
  const liveMap = new Map();
  for (const batch of chunk(videoIds, 50)) {
    if (batch.length === 0) continue;
    const url = `${BASE}/videos?part=snippet&id=${batch.join(',')}&key=${API_KEY}`;
    const data = await fetchJson(url);
    for (const item of data.items || []) {
      if (item.snippet?.liveBroadcastContent === 'live') {
        liveMap.set(item.id, item.snippet);
      }
    }
  }
  return liveMap;
}

// search.list는 title/channelTitle을 HTML 엔티티로 이스케이프해서 반환하므로 디코딩 필요
const HTML_ENTITIES = {
  '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'",
};
function decodeHtmlEntities(str) {
  return str.replace(/&amp;|&lt;|&gt;|&quot;|&#39;|&apos;/g, m => HTML_ENTITIES[m]);
}

async function searchLiveByKeyword(keyword, maxResults = 25) {
  const url = `${BASE}/search?part=snippet&type=video&eventType=live&maxResults=${maxResults}&q=${encodeURIComponent(keyword)}&key=${API_KEY}`;
  const data = await fetchJson(url);
  return (data.items || [])
    .filter(item => item.id?.videoId)
    .map(item => ({
      videoId: item.id.videoId,
      title: decodeHtmlEntities(item.snippet.title),
      channelTitle: decodeHtmlEntities(item.snippet.channelTitle),
      thumbnail:
        item.snippet.thumbnails?.high?.url ||
        item.snippet.thumbnails?.medium?.url ||
        item.snippet.thumbnails?.default?.url,
      matchedKeyword: keyword,
    }));
}

async function main() {
  const [streamsRaw, keywordsRaw] = await Promise.all([
    readFile(STREAMS_PATH, 'utf-8').catch(() => '{"streams":[]}'),
    readFile(KEYWORDS_PATH, 'utf-8'),
  ]);
  const existing = JSON.parse(streamsRaw).streams || [];
  const keywords = JSON.parse(keywordsRaw).keywords || [];

  console.log(`기존 목록 ${existing.length}건 생존 확인 중...`);
  const existingIds = existing.map(s => s.videoId);
  const liveMap = await getLiveSnippets(existingIds);
  const survivors = existing.filter(s => liveMap.has(s.videoId));
  console.log(`  -> 생존 ${survivors.length}건, 제거 ${existing.length - survivors.length}건`);

  const survivorIds = new Set(survivors.map(s => s.videoId));
  const candidateMap = new Map();

  for (const keyword of keywords) {
    try {
      const results = await searchLiveByKeyword(keyword);
      for (const r of results) {
        if (survivorIds.has(r.videoId) || candidateMap.has(r.videoId)) continue;
        candidateMap.set(r.videoId, r);
      }
      console.log(`  검색 "${keyword}": ${results.length}건 조회`);
    } catch (err) {
      console.error(`  검색 실패 "${keyword}":`, err.message);
    }
  }

  console.log(`신규 후보 ${candidateMap.size}건 검증 중...`);
  const candidateIds = [...candidateMap.keys()];
  const verifiedLive = await getLiveSnippets(candidateIds);

  const now = new Date().toISOString();
  const newEntries = [...candidateMap.values()]
    .filter(c => verifiedLive.has(c.videoId))
    .map(c => ({ ...c, addedAt: now }));

  console.log(`  -> 검증 통과 신규 ${newEntries.length}건`);

  const finalList = [...survivors, ...newEntries];
  const output = { lastUpdated: now, streams: finalList };

  await writeFile(STREAMS_PATH, JSON.stringify(output, null, 2) + '\n', 'utf-8');
  console.log(`완료: 총 ${finalList.length}건 (제거 ${existing.length - survivors.length}, 추가 ${newEntries.length})`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
