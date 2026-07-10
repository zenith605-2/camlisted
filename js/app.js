const grid = document.getElementById('grid');
const emptyState = document.getElementById('emptyState');
const searchInput = document.getElementById('searchInput');
const lastUpdatedEl = document.getElementById('lastUpdated');
const modal = document.getElementById('modal');
const modalPlayer = modal.querySelector('.modal-player');
const modalClose = document.getElementById('modalClose');
const modalOpenNewTab = document.getElementById('modalOpenNewTab');

let streams = [];
const pageLoadTime = Date.now();

function render(list) {
  grid.innerHTML = '';
  emptyState.hidden = list.length > 0;

  for (const s of list) {
    const card = document.createElement('div');
    card.className = 'card';
    const liveSnapshot = `https://i.ytimg.com/vi/${encodeURIComponent(s.videoId)}/hqdefault_live.jpg?cb=${pageLoadTime}`;
    card.innerHTML = `
      <div class="thumb-wrap">
        <span class="live-badge">LIVE</span>
        <div class="thumb-half">
          <img src="${s.thumbnail}" alt="${escapeHtml(s.title)} - 대표 썸네일" loading="lazy">
          <span class="thumb-label">대표 썸네일</span>
        </div>
        <div class="thumb-half">
          <img src="${liveSnapshot}" alt="${escapeHtml(s.title)} - 실시간 화면" loading="lazy" onerror="this.closest('.thumb-half').style.display='none'">
          <span class="thumb-label">실시간 화면</span>
        </div>
      </div>
      <div class="card-body">
        <p class="card-title">${escapeHtml(s.title)}</p>
        <p class="card-channel">${escapeHtml(s.channelTitle)}</p>
        <span class="card-keyword">${escapeHtml(s.matchedKeyword || '')}</span>
      </div>
    `;
    card.addEventListener('click', () => openModal(s.videoId));
    grid.appendChild(card);
  }
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}

function openModal(videoId) {
  modalPlayer.innerHTML = `<iframe src="https://www.youtube.com/embed/${encodeURIComponent(videoId)}?autoplay=1" allow="autoplay; encrypted-media" allowfullscreen></iframe>`;
  modalOpenNewTab.href = `https://www.youtube.com/watch?v=${encodeURIComponent(videoId)}`;
  modal.hidden = false;
}

function closeModal() {
  modal.hidden = true;
  modalPlayer.innerHTML = '';
}

modalClose.addEventListener('click', closeModal);
modal.querySelector('.modal-backdrop').addEventListener('click', closeModal);
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !modal.hidden) closeModal();
});

searchInput.addEventListener('input', () => {
  const q = searchInput.value.trim().toLowerCase();
  const filtered = !q
    ? streams
    : streams.filter(s =>
        s.title.toLowerCase().includes(q) ||
        s.channelTitle.toLowerCase().includes(q)
      );
  render(filtered);
});

async function init() {
  try {
    const res = await fetch('data/streams.json', { cache: 'no-store' });
    const data = await res.json();
    streams = data.streams || [];
    if (data.lastUpdated) {
      lastUpdatedEl.textContent = `마지막 갱신: ${new Date(data.lastUpdated).toLocaleString('ko-KR')}`;
    }
    render(streams);
  } catch (err) {
    emptyState.textContent = '목록을 불러오지 못했습니다.';
    emptyState.hidden = false;
    console.error(err);
  }
}

init();
