const SUPABASE_URL = 'https://chgodrjjalsrgyxuwjyq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_IPRYfUNkhfTLWohT6gjXYw_APGRcPuP';

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const authArea = document.getElementById('authArea');
const feedbackForm = document.getElementById('feedbackForm');
const feedbackTitle = document.getElementById('feedbackTitle');
const feedbackContent = document.getElementById('feedbackContent');
const feedbackLoginHint = document.getElementById('feedbackLoginHint');
const feedbackList = document.getElementById('feedbackList');

let currentUser = null;
let isAdmin = false;
let myUpvotedPostIds = new Set();

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}

function renderAuthArea() {
  if (currentUser) {
    authArea.innerHTML = `
      <span class="auth-user">${escapeHtml(currentUser.email || '')}</span>
      <button type="button" id="logoutBtn" class="auth-btn">${escapeHtml(t('logout_button'))}</button>
    `;
    document.getElementById('logoutBtn').addEventListener('click', () => sb.auth.signOut());
    feedbackForm.hidden = false;
    feedbackLoginHint.hidden = true;
  } else {
    authArea.innerHTML = `<button type="button" id="loginBtn" class="auth-btn">${escapeHtml(t('login_button'))}</button>`;
    document.getElementById('loginBtn').addEventListener('click', () => {
      sb.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo: window.location.origin + window.location.pathname },
      });
    });
    feedbackForm.hidden = true;
    feedbackLoginHint.hidden = false;
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

const STATUS_LABELS = { open: 'feedback_status_open', planned: 'feedback_status_planned', done: 'feedback_status_done', declined: 'feedback_status_declined' };

function postHtml(post) {
  const hasUpvoted = myUpvotedPostIds.has(post.id);
  const canDelete = currentUser && (currentUser.id === post.user_id || isAdmin);
  const statusOptions = Object.keys(STATUS_LABELS)
    .map(key => `<option value="${key}" ${post.status === key ? 'selected' : ''}>${escapeHtml(t(STATUS_LABELS[key]))}</option>`)
    .join('');
  return `
    <div class="feedback-item" data-post-id="${post.id}">
      <div class="feedback-item-main">
        <button type="button" class="feedback-upvote-btn ${hasUpvoted ? 'active' : ''}" data-post-id="${post.id}" ${!currentUser || hasUpvoted ? 'disabled' : ''}>
          ▲ ${post.upvote_count}
        </button>
        <div class="feedback-item-body">
          <p class="feedback-item-title">${escapeHtml(post.title)}</p>
          <p class="feedback-item-content">${escapeHtml(post.content)}</p>
          <span class="feedback-status feedback-status-${post.status}">${escapeHtml(t(STATUS_LABELS[post.status]))}</span>
          <span class="feedback-author">${escapeHtml(post.authorName)}</span>
        </div>
      </div>
      <div class="feedback-item-actions">
        ${isAdmin ? `<select class="feedback-status-select" data-post-id="${post.id}">${statusOptions}</select>` : ''}
        ${canDelete ? `<button type="button" class="feedback-delete-btn" data-post-id="${post.id}">${escapeHtml(t('feedback_delete_button'))}</button>` : ''}
      </div>
    </div>
  `;
}

async function loadPosts() {
  feedbackList.textContent = t('loading');
  const { data: posts, error } = await sb
    .from('feedback_posts')
    .select('*')
    .order('upvote_count', { ascending: false })
    .order('created_at', { ascending: false });
  if (error) {
    feedbackList.textContent = t('feedback_load_failed');
    return;
  }

  const userIds = [...new Set(posts.map(p => p.user_id).filter(Boolean))];
  const namesMap = new Map();
  if (userIds.length) {
    const { data: profiles } = await sb.from('profiles').select('id, display_name').in('id', userIds);
    for (const p of profiles || []) namesMap.set(p.id, p.display_name);
  }

  myUpvotedPostIds = new Set();
  if (currentUser) {
    const { data: myUpvotes } = await sb.from('feedback_upvotes').select('post_id').eq('user_id', currentUser.id);
    for (const u of myUpvotes || []) myUpvotedPostIds.add(u.post_id);
  }

  if (!posts.length) {
    feedbackList.textContent = t('feedback_empty');
    return;
  }

  feedbackList.innerHTML = posts
    .map(p => ({ ...p, authorName: namesMap.get(p.user_id) || t('anonymous') }))
    .map(postHtml)
    .join('');
}

feedbackForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  if (!currentUser) return;
  const title = feedbackTitle.value.trim();
  const content = feedbackContent.value.trim();
  if (!title || !content) return;
  const { error } = await sb.from('feedback_posts').insert({ user_id: currentUser.id, title, content });
  if (error) {
    alert(t('feedback_submit_failed', { message: error.message }));
    return;
  }
  feedbackTitle.value = '';
  feedbackContent.value = '';
  await loadPosts();
});

feedbackList.addEventListener('click', async (e) => {
  const upvoteBtn = e.target.closest('.feedback-upvote-btn');
  if (upvoteBtn) {
    if (!currentUser) return;
    const postId = Number(upvoteBtn.dataset.postId);
    upvoteBtn.disabled = true;
    const { error } = await sb.from('feedback_upvotes').insert({ post_id: postId, user_id: currentUser.id });
    if (error) {
      upvoteBtn.disabled = false;
      return;
    }
    await loadPosts();
    return;
  }

  const deleteBtn = e.target.closest('.feedback-delete-btn');
  if (deleteBtn) {
    if (!confirm(t('feedback_delete_confirm'))) return;
    const postId = Number(deleteBtn.dataset.postId);
    const { error } = await sb.from('feedback_posts').delete().eq('id', postId);
    if (error) {
      alert(t('feedback_delete_failed', { message: error.message }));
      return;
    }
    await loadPosts();
  }
});

feedbackList.addEventListener('change', async (e) => {
  const select = e.target.closest('.feedback-status-select');
  if (!select || !isAdmin) return;
  const postId = Number(select.dataset.postId);
  const { error } = await sb.from('feedback_posts').update({ status: select.value }).eq('id', postId);
  if (error) alert(t('feedback_status_failed', { message: error.message }));
});

sb.auth.onAuthStateChange(async (_event, session) => {
  currentUser = session?.user || null;
  await checkAdmin();
  renderAuthArea();
  await loadPosts();
});

async function init() {
  applyStaticTranslations();
  const { data: { session } } = await sb.auth.getSession();
  currentUser = session?.user || null;
  await checkAdmin();
  renderAuthArea();
  await loadPosts();
}

init();
