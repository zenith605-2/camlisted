// publishable key는 공개되어도 안전한 키입니다 (RLS로 보호됨). 실제 수정/삭제 권한은
// profiles.is_admin + RLS 정책(sql/007_admin.sql)이 서버 쪽에서 검증합니다.
const SUPABASE_URL = 'https://chgodrjjalsrgyxuwjyq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_IPRYfUNkhfTLWohT6gjXYw_APGRcPuP';

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const authArea = document.getElementById('authArea');
const accessDenied = document.getElementById('accessDenied');
const adminTabs = document.getElementById('adminTabs');
const adminList = document.getElementById('adminList');
const userList = document.getElementById('userList');
const tabFlagged = document.getElementById('tabFlagged');
const tabUsers = document.getElementById('tabUsers');

let currentUser = null;
let isAdmin = false;

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}

function renderAuthArea() {
  if (currentUser) {
    authArea.innerHTML = `
      <span class="auth-user">${escapeHtml(currentUser.email || '')}</span>
      <button type="button" id="logoutBtn" class="auth-btn">로그아웃</button>
    `;
    document.getElementById('logoutBtn').addEventListener('click', () => sb.auth.signOut());
  } else {
    authArea.innerHTML = `<button type="button" id="loginBtn" class="auth-btn">Google로 로그인</button>`;
    document.getElementById('loginBtn').addEventListener('click', () => {
      sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: window.location.origin + window.location.pathname } });
    });
  }
}

async function checkAdmin() {
  if (!currentUser) {
    isAdmin = false;
    return;
  }
  const { data } = await sb.from('profiles').select('is_admin').eq('id', currentUser.id).maybeSingle();
  isAdmin = !!data?.is_admin;
}

function rowHtml(r) {
  return `
    <div class="admin-row" data-video-id="${escapeHtml(r.video_id)}" data-visibility="${r.visibility}">
      <img class="admin-thumb" src="${r.thumbnail || ''}" alt="">
      <div class="admin-info">
        <div class="admin-title">${escapeHtml(r.title || r.video_id)}</div>
        <div class="admin-meta">
          채널: ${escapeHtml(r.channel_title || '(정보 없음)')} ·
          👎 비추 ${r.downvote_count || 0} · 🚩 신고 ${r.report_count || 0} ·
          상태: ${r.visibility === 'hidden' ? '숨김' : '일반'}
        </div>
        <a href="https://www.youtube.com/watch?v=${encodeURIComponent(r.video_id)}" target="_blank" rel="noopener">유튜브에서 보기</a>
      </div>
      <div class="admin-actions">
        <button type="button" class="toggle-visibility-btn">${r.visibility === 'hidden' ? '목록에 표시' : '숨기기'}</button>
        <button type="button" class="delete-btn">영구 삭제</button>
      </div>
    </div>
  `;
}

async function loadFlagged() {
  adminList.textContent = '불러오는 중...';
  const { data, error } = await sb
    .from('streams')
    .select('*')
    .or('visibility.eq.hidden,downvote_count.gt.0,report_count.gt.0')
    .order('downvote_count', { ascending: false });

  if (error) {
    adminList.textContent = '목록을 불러오지 못했습니다: ' + error.message;
    return;
  }
  if (!data || data.length === 0) {
    adminList.textContent = '신고·비추천된 항목이 없습니다.';
    return;
  }
  adminList.innerHTML = data.map(rowHtml).join('');
}

adminList.addEventListener('click', async (e) => {
  const row = e.target.closest('.admin-row');
  if (!row) return;
  const videoId = row.dataset.videoId;

  if (e.target.closest('.toggle-visibility-btn')) {
    const next = row.dataset.visibility === 'hidden' ? 'listed' : 'hidden';
    const { error } = await sb.from('streams').update({ visibility: next }).eq('video_id', videoId);
    if (error) {
      alert('처리 실패: ' + error.message);
      return;
    }
    await loadFlagged();
  }

  if (e.target.closest('.delete-btn')) {
    if (!confirm('정말 영구 삭제하시겠습니까? 되돌릴 수 없습니다.')) return;
    const { error } = await sb.from('streams').delete().eq('video_id', videoId);
    if (error) {
      alert('삭제 실패: ' + error.message);
      return;
    }
    // 삭제한 videoId를 차단 목록에 기록해, 다음날 자동 검색/채널스캔이 다시 넣지 못하게 한다.
    await sb.from('blocklist').insert({ video_id: videoId, blocked_by: currentUser.id });
    await loadFlagged();
  }
});

function userRowHtml(u) {
  return `
    <div class="admin-row" data-user-id="${escapeHtml(u.id)}" data-is-admin="${u.is_admin}">
      <img class="admin-thumb user-avatar" src="${u.avatar_url || ''}" alt="">
      <div class="admin-info">
        <div class="admin-title">${escapeHtml(u.display_name || '(닉네임 없음)')}</div>
        <div class="admin-meta">
          제보 ${u.submissionCount}건 · 가입일 ${new Date(u.created_at).toLocaleDateString('ko-KR')} ·
          ${u.is_admin ? '관리자' : '일반 유저'}
        </div>
      </div>
      <div class="admin-actions">
        <button type="button" class="toggle-admin-btn">${u.is_admin ? '관리자 해제' : '관리자로 지정'}</button>
      </div>
    </div>
  `;
}

async function loadUsers() {
  userList.textContent = '불러오는 중...';
  const [{ data: profiles, error: profileErr }, { data: submissions, error: subErr }] = await Promise.all([
    sb.from('profiles').select('id, display_name, avatar_url, is_admin, created_at').order('created_at'),
    sb.from('streams').select('added_by').not('added_by', 'is', null),
  ]);
  if (profileErr) {
    userList.textContent = '유저 목록을 불러오지 못했습니다: ' + profileErr.message;
    return;
  }
  const counts = new Map();
  if (!subErr) {
    for (const row of submissions || []) {
      counts.set(row.added_by, (counts.get(row.added_by) || 0) + 1);
    }
  }
  const rows = (profiles || []).map(u => ({ ...u, submissionCount: counts.get(u.id) || 0 }));
  if (!rows.length) {
    userList.textContent = '가입한 유저가 없습니다.';
    return;
  }
  userList.innerHTML = rows.map(userRowHtml).join('');
}

userList.addEventListener('click', async (e) => {
  const row = e.target.closest('.admin-row');
  if (!row || !e.target.closest('.toggle-admin-btn')) return;
  const userId = row.dataset.userId;
  const nextIsAdmin = row.dataset.isAdmin !== 'true';
  if (!confirm(nextIsAdmin ? '이 유저를 관리자로 지정하시겠습니까?' : '이 유저의 관리자 권한을 해제하시겠습니까?')) return;
  const { error } = await sb.rpc('set_user_admin', { p_user_id: userId, p_is_admin: nextIsAdmin });
  if (error) {
    alert('처리 실패: ' + error.message);
    return;
  }
  await loadUsers();
});

tabFlagged.addEventListener('click', () => {
  tabFlagged.classList.add('active');
  tabUsers.classList.remove('active');
  adminList.hidden = false;
  userList.hidden = true;
});

tabUsers.addEventListener('click', () => {
  tabUsers.classList.add('active');
  tabFlagged.classList.remove('active');
  adminList.hidden = true;
  userList.hidden = false;
  loadUsers();
});

async function refresh() {
  renderAuthArea();
  await checkAdmin();
  if (!isAdmin) {
    accessDenied.hidden = false;
    adminTabs.hidden = true;
    adminList.hidden = true;
    userList.hidden = true;
    return;
  }
  accessDenied.hidden = true;
  adminTabs.hidden = false;
  adminList.hidden = false;
  await loadFlagged();
}

sb.auth.onAuthStateChange(async (_event, session) => {
  currentUser = session?.user || null;
  await refresh();
});

async function init() {
  const { data: { session } } = await sb.auth.getSession();
  currentUser = session?.user || null;
  await refresh();
}

init();
