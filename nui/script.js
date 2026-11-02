const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ws-squad';

let T = {};   // filled from the selected `Locales` language (sent by the client script)
const t = (k) => T[k] || k;

function applyLocale(loc) {
  if (!loc) return;
  T = loc;
  document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
  document.querySelectorAll('[data-i18n-ph]').forEach((el) => { el.placeholder = t(el.dataset.i18nPh); });
  document.querySelectorAll('[data-i18n-title]').forEach((el) => { el.title = t(el.dataset.i18nTitle); });
  const root = document.documentElement.style;
  root.setProperty('--t-kick', JSON.stringify(t('ui_kick')));
  root.setProperty('--t-yoursquad', JSON.stringify(' ' + t('ui_your_squad')));
  $('maxLbl').textContent = t('ui_max_members').replace('%s', maxLimit);
}

let state = { list: [], squad: null, invite: null, me: 0 };
let maxLimit = 10;
let view = 'list';          // 'list' (home) | 'create' | 'join' | 'manage'
let prevSquadId;            // undefined until first update
let selectedId = null;
let lastHealth = {};

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function post(name, data = {}) {
  return fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).catch(() => {});
}

/* ===== MENU RENDER ===== */
function renderMenu() {
  const { list, squad, invite, me } = state;

  // auto-open management when a squad is created/joined; fall back to list when it ends
  const curId = squad ? squad.id : null;
  if (prevSquadId !== undefined && curId !== prevSquadId && squad) view = 'manage';
  if (!squad && view === 'manage') view = 'list';
  prevSquadId = curId;

  // invite banner
  if (invite && !squad) {
    $('inviteBox').classList.remove('hidden');
    $('inviteText').textContent = `${t('ui_invited_to')}: ${invite.name} — ${t('ui_by')} ${invite.from}`;
  } else {
    $('inviteBox').classList.add('hidden');
  }

  if (squad && view === 'manage') {
    $('viewBrowse').classList.add('hidden');
    $('viewCreate').classList.add('hidden');
    $('viewJoin').classList.add('hidden');
    $('viewSquad').classList.remove('hidden');
    const isLeader = squad.leader === me;
    $('mySquadName').textContent = squad.name;
    $('mySquadCount').textContent = `${squad.members.length}/${squad.max}`;
    document.querySelectorAll('.leader-only').forEach((el) => el.classList.toggle('hidden', !isLeader));
    $('memberList').innerHTML = squad.members.map((m) => {
      const kickable = isLeader && m.src !== me;
      return `
      <div class="member ${kickable ? 'kickable' : ''}" ${kickable ? `data-kick="${m.src}" title="${esc(t('ui_kick_title'))}"` : ''}>
        <span class="nm">${esc(m.name)}${m.src === me ? ` <small>(${t('ui_you')})</small>` : ''}</span>
        ${m.leader ? `<span class="tag">★ ${t('ui_leader')}</span>` : ''}
        <span class="id">${t('ui_id')}: ${m.src}</span>
      </div>`;
    }).join('');
    return;
  }

  // squad exists in state -> create/join screens are not allowed
  if (squad && (view === 'create' || view === 'join')) view = 'list';

  if (!squad && view === 'join' && !list.find((x) => x.id === selectedId)) view = 'list';

  const showHome = view === 'list';
  $('viewSquad').classList.add('hidden');
  $('viewBrowse').classList.toggle('hidden', !showHome);
  $('viewCreate').classList.toggle('hidden', view !== 'create');
  $('viewJoin').classList.toggle('hidden', view !== 'join');

  // home = all squads
  $('btnShowCreate').classList.toggle('hidden', !!squad);
  $('listHint').textContent = squad ? t('ui_hint_manage') : (list.length ? t('ui_hint_join') : '');
  if (selectedId && !list.find((x) => x.id === selectedId)) selectedId = null;
  if (!list.length) {
    $('squadList').innerHTML = `<div class="empty">${t('ui_no_squads')}</div>`;
  } else {
    $('squadList').innerHTML = list.map((s) => {
      const mine = squad && squad.id === s.id;
      return `
      <div class="squad-item ${mine ? 'mine' : ''} ${s.count >= s.max ? 'full' : ''} ${squad && !mine ? 'nojoin' : ''}" data-id="${s.id}">
        <span class="n">${esc(s.name)}</span>
        <span class="c">${s.count}/${s.max}</span>
        <span class="l">★ ${t('ui_leader')}: ${esc(s.leader)}</span>
      </div>`;
    }).join('');
  }
  const sel = list.find((x) => x.id === selectedId);
  $('selectedSquad').textContent = sel ? sel.name : '—';
}

/* ===== HUD RENDER ===== */
function renderHud(d) {
  if (!d || !d.show || !d.members || !d.members.length) {
    $('hud').classList.add('hidden');
    lastHealth = {};
    return;
  }
  $('hud').classList.remove('hidden');
  $('hudTitle').textContent = d.name;
  const box = $('hudMembers');
  const seen = new Set();
  d.members.forEach((m) => {
    seen.add(String(m.src));
    let el = box.querySelector(`[data-src="${m.src}"]`);
    if (!el) {
      el = document.createElement('div');
      el.className = 'hud-m';
      el.dataset.src = m.src;
      el.innerHTML = `<div class="hud-top"><span><span class="heart">❤</span><span class="nm"></span></span><span class="pct"></span></div><div class="hud-bar"><div class="hud-fill"></div></div>`;
      box.appendChild(el);
    }
    el.classList.toggle('me', !!m.me);
    el.classList.toggle('dead', !!m.dead);
    el.querySelector('.nm').textContent = (m.leader ? '★ ' : '') + m.name;
    el.querySelector('.pct').textContent = m.dead ? t('ui_dead') : `${m.health}%`;
    el.querySelector('.heart').textContent = m.dead ? '✝' : '❤';
    el.querySelector('.heart').classList.toggle('low', m.health <= 30);
    el.querySelector('.hud-fill').style.width = `${m.health}%`;
    const prev = lastHealth[m.src];
    if (prev !== undefined && m.health < prev) {
      el.classList.remove('flash'); void el.offsetWidth; el.classList.add('flash');
    }
    lastHealth[m.src] = m.health;
  });
  // keep order
  d.members.forEach((m) => box.appendChild(box.querySelector(`[data-src="${m.src}"]`)));
  box.querySelectorAll('.hud-m').forEach((el) => { if (!seen.has(el.dataset.src)) el.remove(); });
}

/* ===== EVENTS ===== */
window.addEventListener('message', (e) => {
  const { action, data } = e.data || {};
  if (action === 'menu') {
    maxLimit = data.maxLimit || 10;
    if (data.locale) applyLocale(data.locale);
    $('inMax').max = maxLimit;
    if (!$('inMax').dataset.init) { $('inMax').value = data.defaultMax || 6; $('inMax').dataset.init = '1'; }
    state = { list: data.list || [], squad: data.squad || null, invite: data.invite || null, me: data.me };
    if (data.open && $('menu').classList.contains('hidden')) { view = 'list'; selectedId = null; }
    $('menu').classList.remove('hidden');
    renderMenu();
  } else if (action === 'close') {
    $('menu').classList.add('hidden');
    view = 'list';
    selectedId = null;
    closeModals();
  } else if (action === 'locale') {
    applyLocale(data);
  } else if (action === 'hud') {
    renderHud(data);
  }
});

const MODALS = ['modalInvite', 'modalCode', 'modalLeave'];
const closeModals = () => MODALS.forEach((id) => $(id).classList.add('hidden'));
const openModal = (id, focusId) => { closeModals(); $(id).classList.remove('hidden'); $(focusId).value = ''; $(focusId).focus(); };

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape' || $('menu').classList.contains('hidden')) return;
  if (MODALS.some((id) => !$(id).classList.contains('hidden'))) { closeModals(); return; }
  post('close');
});

$('btnOpenInvite').onclick = () => openModal('modalInvite', 'inInviteId');
$('btnOpenCode').onclick = () => openModal('modalCode', 'inNewCode');
document.querySelectorAll('[data-close-modal]').forEach((b) => { b.onclick = closeModals; });
MODALS.forEach((id) => $(id).addEventListener('mousedown', (e) => { if (e.target.id === id) closeModals(); }));

$('btnClose').onclick = () => post('close');

$('squadList').addEventListener('click', (e) => {
  const item = e.target.closest('.squad-item');
  if (!item) return;
  const id = Number(item.dataset.id);
  if (state.squad) {
    if (state.squad.id === id) { view = 'manage'; renderMenu(); }   // only own squad is openable
    return;
  }
  const sq = state.list.find((x) => x.id === id);
  if (!sq || sq.count >= sq.max) return;
  selectedId = id;
  view = 'join';
  renderMenu();
  $('inJoinCode').focus();
});

$('btnCreate').onclick = () => {
  const name = $('inName').value.trim();
  const code = $('inCode').value.trim();
  let max = parseInt($('inMax').value, 10);
  if (!name || !code || !max) return;
  max = Math.max(1, Math.min(maxLimit, max));
  $('inMax').value = max;
  post('create', { name, code, max });
  $('inName').value = ''; $('inCode').value = '';
};

$('btnJoin').onclick = () => {
  const code = $('inJoinCode').value.trim();
  if (!selectedId || !code) return;
  post('join', { id: selectedId, code });
  $('inJoinCode').value = '';
};
$('inJoinCode').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('btnJoin').click(); });
$('inCode').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('btnCreate').click(); });

$('btnShowCreate').onclick = () => { view = 'create'; renderMenu(); $('inName').focus(); };
$('btnBackCreate').onclick = () => { view = 'list'; renderMenu(); };
$('btnBackJoin').onclick = () => { view = 'list'; selectedId = null; renderMenu(); };

$('btnAccept').onclick = () => post('acceptInvite');
$('btnDecline').onclick = () => post('declineInvite');

$('btnInvite').onclick = () => {
  const id = parseInt($('inInviteId').value, 10);
  if (!id) return;
  post('invite', { id });
  $('inInviteId').value = '';
  closeModals();
};
$('inInviteId').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('btnInvite').click(); });

$('btnBack').onclick = () => { view = 'list'; renderMenu(); };

$('btnChangeCode').onclick = () => {
  const code = $('inNewCode').value.trim();
  if (!code) return;
  post('changeCode', { code });
  $('inNewCode').value = '';
  closeModals();
};
$('inNewCode').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('btnChangeCode').click(); });

$('btnLeave').onclick = () => {
  const sq = state.squad;
  const leaderWithOthers = sq && sq.leader === state.me && sq.members.length > 1;
  if (leaderWithOthers) { closeModals(); $('modalLeave').classList.remove('hidden'); return; }
  post('leave');
};
$('btnConfirmLeave').onclick = () => { closeModals(); post('leave'); };

$('memberList').addEventListener('click', (e) => {
  const b = e.target.closest('[data-kick]');
  if (b) post('kick', { id: Number(b.dataset.kick) });
});

