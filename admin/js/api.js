const API_BASE = window.location.origin + '/api/admin';

function getToken() { return localStorage.getItem('adminToken'); }
function getName()  { return localStorage.getItem('adminName') || 'Secretary'; }
function getRole()  { return localStorage.getItem('adminRole') || 'secretary'; }

function saveAuth(token, name, role) {
  localStorage.setItem('adminToken', token);
  localStorage.setItem('adminName', name);
  localStorage.setItem('adminRole', role);
}

function clearAuth() {
  localStorage.removeItem('adminToken');
  localStorage.removeItem('adminName');
  localStorage.removeItem('adminRole');
}

function requireAuth() {
  if (!getToken()) { window.location.href = '/admin/index.html'; }
}

async function apiFetch(path, options = {}) {
  const token = getToken();
  const res = await fetch(API_BASE + path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: 'Bearer ' + token } : {}),
      ...(options.headers || {}),
    },
  });

  // Only redirect on 401 if we already have a token (expired session).
  // If there's no token, this is a failed login attempt — let the caller handle it.
  if (res.status === 401 && getToken()) {
    clearAuth();
    window.location.href = '/admin/index.html';
    return;
  }

  const data = await res.json();
  return { ok: res.ok, status: res.status, data };
}

function showToast(message, type = '') {
  let toast = document.getElementById('toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'toast';
    toast.className = 'toast';
    document.body.appendChild(toast);
  }
  toast.textContent = message;
  toast.className = 'toast show' + (type ? ' ' + type : '');
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => { toast.className = 'toast'; }, 3000);
}

function formatDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' });
}

function formatDateTime(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric',
    hour: '2-digit', minute: '2-digit' });
}

function badgeHtml(status) {
  const map = {
    pending:  ['badge-pending',  '⏳ Pending'],
    approved: ['badge-approved', '✓ Approved'],
    rejected: ['badge-rejected', '✗ Rejected'],
    draft:    ['badge-draft',    '✏ Draft'],
  };
  const [cls, label] = map[status] || map.draft;
  return `<span class="badge ${cls}">${label}</span>`;
}

function uploadsUrl(filename) {
  return filename ? window.location.origin + '/uploads/' + filename : null;
}
