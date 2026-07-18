// 전용 응원(방명록) 페이지 — 메인 헤더에서 분리해 cheers.html에서 단독 동작한다.
const SUPABASE_URL = 'https://chgodrjjalsrgyxuwjyq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_IPRYfUNkhfTLWohT6gjXYw_APGRcPuP';
const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const cheerList = document.getElementById('cheerList');
const cheerForm = document.getElementById('cheerForm');
const cheerInput = document.getElementById('cheerInput');

let currentUser = null;
let isAdmin = false;
let myName = null;

function escapeHtml(str) {
  return String(str ?? '').replace(/[&<>"']/g, c => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

async function loadCheers() {
  const { data, error } = await sb
    .from('cheers')
    .select('id, name, content, created_at')
    .order('created_at', { ascending: false })
    .limit(200);
  if (error) { cheerList.innerHTML = `<span class="cheer-empty">${escapeHtml(error.message)}</span>`; return; }
  cheerList.innerHTML = (data || []).map(c => `
    <span class="cheer-chip" data-cheer-id="${c.id}">
      <b>${escapeHtml(c.name || t('anonymous'))}</b> ${escapeHtml(c.content)}
      ${isAdmin ? `<button type="button" class="cheer-delete-btn" data-cheer-id="${c.id}" title="delete">✕</button>` : ''}
    </span>
  `).join('') || `<span class="cheer-empty">${escapeHtml(t('cheer_empty'))}</span>`;
}

cheerForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const content = cheerInput.value.trim();
  if (!content) return;
  const { error } = await sb.from('cheers').insert({ content, name: myName, user_id: currentUser?.id || null });
  if (error) { alert(error.message); return; }
  cheerInput.value = '';
  loadCheers();
});

cheerList.addEventListener('click', async (e) => {
  const btn = e.target.closest('.cheer-delete-btn');
  if (!btn || !isAdmin) return;
  await sb.from('cheers').delete().eq('id', btn.dataset.cheerId);
  loadCheers();
});

async function init() {
  const { data: { session } } = await sb.auth.getSession();
  currentUser = session?.user || null;
  if (currentUser) {
    // 로그인 상태면 관리자 여부(삭제 버튼)와 표시 이름을 가져온다. 세션은 메인과 공유됨.
    const { data } = await sb.from('profiles').select('is_admin, display_name').eq('id', currentUser.id).maybeSingle();
    isAdmin = !!data?.is_admin;
    myName = data?.display_name || currentUser.user_metadata?.full_name || null;
  }
  loadCheers();
}
init();
