# 유튜브 실시간 CCTV 모음

유튜브 라이브 중인 CCTV 영상을 키워드 검색으로 자동 수집해 보여주는 정적 사이트입니다.
매일 `scripts/update.mjs`가 실행되어 중지된 스트림은 제거하고 신규 스트림을 추가합니다.

## 구조
- `index.html`, `css/`, `js/` — 정적 프론트엔드
- `data/streams.json` — 현재 라이브 목록 (자동 갱신 대상, 현재는 샘플 더미 데이터)
- `config/keywords.json` — 검색에 사용할 키워드 목록 (자유롭게 추가/수정 가능)
- `config/exclude-keywords.json` — 제목/채널명에 포함되면 걸러내는 제외 키워드 (뉴스/방송 채널 오탐 방지)
- `scripts/update.mjs` — YouTube Data API로 목록을 갱신하는 Node.js 스크립트
- `.github/workflows/update.yml` — 매일 자동 실행 워크플로

## 1. YouTube Data API 키 발급 (필수)
1. https://console.cloud.google.com 접속 후 새 프로젝트 생성
2. 좌측 메뉴 "API 및 서비스" → "라이브러리" → "YouTube Data API v3" 검색 → 사용 설정
3. "API 및 서비스" → "사용자 인증 정보" → "사용자 인증 정보 만들기" → "API 키" 선택
4. 발급된 키를 복사 (필요 시 "키 제한"에서 YouTube Data API v3로 제한 권장)

무료 할당량은 1일 10,000 unit이며, 본 스크립트는 키워드 15개 기준 약 1,500~2,000 unit을 사용합니다.

## 2. 로컬에서 테스트
```bash
cd cctv-live-list
YOUTUBE_API_KEY=발급받은키 node scripts/update.mjs
```
Windows PowerShell:
```powershell
$env:YOUTUBE_API_KEY="발급받은키"; node scripts/update.mjs
```
실행 후 `data/streams.json`이 실제 라이브 CCTV 목록으로 갱신됩니다. `index.html`을 브라우저로 열어 확인하세요.

## 3. GitHub에 배포 (자동 갱신 + 무료 호스팅)
1. GitHub에 새 저장소 생성 후 이 폴더를 push
2. 저장소 Settings → Secrets and variables → Actions → New repository secret
   - Name: `YOUTUBE_API_KEY`, Value: 발급받은 키
3. Settings → Pages → Source를 `main` 브랜치 `/ (root)`로 설정 → 배포된 URL 확인
4. Actions 탭에서 "Update CCTV live list" 워크플로가 매일 KST 06:00에 자동 실행됩니다.
   (Actions 탭 → 워크플로 선택 → "Run workflow"로 즉시 수동 실행도 가능)

## 키워드 커스터마이즈
`config/keywords.json`의 `keywords` 배열에 검색어를 추가하면 다음 실행부터 반영됩니다.
너무 일반적인 키워드는 CCTV가 아닌 영상을 많이 잡아낼 수 있으니, 결과를 보고 조정하세요.

## 오탐(false positive) 제외
"CCTV"는 감시카메라 외에 중국 CCTV(중국중앙방송, China Central Television) 같은 방송사 이름과도 겹쳐서,
뉴스/드라마 채널이 섞여 들어올 수 있습니다. `config/exclude-keywords.json`에 제목/채널명 키워드를 추가하면
다음 실행부터 기존 목록에서도 자동으로 걸러집니다.
