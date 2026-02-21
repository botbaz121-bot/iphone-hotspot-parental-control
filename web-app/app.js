(() => {
  const WEB_BUILD = '0.1.76-web';
  const API_BASE_KEY = 'spotchecker.web.apiBase';
  const SESSION_KEY = 'spotchecker.web.sessionToken';
  const PREFS_KEY = 'spotchecker.web.prefs.v1';

  const DAY_KEYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  const DAY_LABEL = { sun: 'S', mon: 'M', tue: 'T', wed: 'W', thu: 'T', fri: 'F', sat: 'S' };

  const CHILD_TILE_GRADIENTS = [
    'linear-gradient(135deg, #f15561 0%, #d62f59 100%)',
    'linear-gradient(135deg, #ffb22f 0%, #ff7f20 100%)',
    'linear-gradient(135deg, #ffe13c 0%, #d4b418 100%)',
    'linear-gradient(135deg, #51da64 0%, #2cc45e 100%)',
    'linear-gradient(135deg, #33c0f6 0%, #0f94cf 100%)',
    'linear-gradient(135deg, #7f76ff 0%, #5f4de2 100%)'
  ];

  const PARENT_TILE_GRADIENTS = [
    'linear-gradient(135deg, #2d7fff 0%, #2464dd 100%)',
    'linear-gradient(135deg, #27b59e 0%, #16957e 100%)',
    'linear-gradient(135deg, #db7b33 0%, #b75f1f 100%)',
    'linear-gradient(135deg, #9652ea 0%, #6d35c5 100%)'
  ];

  const state = {
    apiBase: localStorage.getItem(API_BASE_KEY) || 'https://api.spotchecker.app',
    sessionToken: localStorage.getItem(SESSION_KEY) || '',
    me: null,
    household: null,
    members: [],
    invites: [],
    devices: [],
    eventsByDevice: {},
    pendingByDevice: {},
    selectedChildId: null,
    selectedParentKey: null,
    selectedDayByDevice: {},
    notifPrefs: loadNotificationPrefs(),
    notice: null,
    noticeType: 'ok',
    busy: false
  };

  const app = document.getElementById('app');

  function loadNotificationPrefs() {
    try {
      const raw = localStorage.getItem(PREFS_KEY);
      if (!raw) return {};
      const parsed = JSON.parse(raw);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch {
      return {};
    }
  }

  function saveNotificationPrefs() {
    localStorage.setItem(PREFS_KEY, JSON.stringify(state.notifPrefs));
  }

  function parseHashSession() {
    const raw = String(location.hash || '').replace(/^#/, '');
    if (!raw) return;
    const p = new URLSearchParams(raw);
    const token = (p.get('sessionToken') || '').trim();
    if (!token) return;
    state.sessionToken = token;
    localStorage.setItem(SESSION_KEY, token);
    history.replaceState(null, '', location.pathname + location.search);
  }

  function friendlyError(err) {
    const m = String(err?.message || err || '').toLowerCase();
    if (m.includes('unauthorized') || m.includes('401')) return 'Your session expired. Please sign in again.';
    if (m.includes('owner_required')) return 'Only the owner can do that action.';
    if (m.includes('cannot_delete_owner')) return 'The owner profile cannot be deleted.';
    if (m.includes('invite_expired')) return 'That invite has expired.';
    if (m.includes('already_resolved')) return 'This request was already handled.';
    if (m.includes('not_found')) return 'That item was not found.';
    if (m.includes('network')) return 'Network error. Check connection and try again.';
    return String(err?.message || 'Something went wrong.');
  }

  function setNotice(message, type = 'ok') {
    state.notice = message ? String(message) : null;
    state.noticeType = type;
    render();
  }

  function escapeHtml(v) {
    return String(v ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  }

  async function api(path, opts = {}) {
    const headers = { 'Content-Type': 'application/json', ...(opts.headers || {}) };
    if (state.sessionToken) headers.Authorization = `Bearer ${state.sessionToken}`;

    const res = await fetch(state.apiBase + path, { ...opts, headers });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = { raw: text };
    }
    if (!res.ok) {
      throw new Error(data?.error || data?.detail || data?.message || `HTTP ${res.status}`);
    }
    return data;
  }

  function minsToHm(mins) {
    const m = Number(mins || 0);
    if (m <= 0) return '0m';
    const h = Math.floor(m / 60);
    const r = m % 60;
    if (!h) return `${r}m`;
    if (!r) return `${h}h`;
    return `${h}h ${r}m`;
  }

  function formatDateTime(ts) {
    if (!ts) return 'Never';
    try {
      return new Date(Number(ts)).toLocaleString([], { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' });
    } catch {
      return 'Unknown';
    }
  }

  function eventLabel(trigger) {
    const t = String(trigger || '').toLowerCase();
    if (t === 'policy_fetch') return 'Phone online';
    if (t === 'extra_time_requested') return 'Extra time requested';
    if (t === 'extra_time_applied') return 'Extra time applied';
    if (t === 'extra_time_denied') return 'Extra time denied';
    if (t.includes('battery')) return 'Battery automation ran';
    if (t.includes('wifi') || t.includes('network')) return 'Network automation ran';
    if (t.includes('time')) return 'Scheduled automation ran';
    return trigger || 'Update';
  }

  function parentEntries() {
    const members = state.members
      .filter(m => String(m.status || '').toLowerCase() === 'active')
      .map(m => ({
        key: `member:${m.id}`,
        type: 'member',
        id: m.id,
        parentId: m.parentId,
        title: m.displayName || m.email || 'Parent',
        subtitle: m.role === 'owner' ? 'Owner' : 'Coparent',
        role: m.role,
        status: m.status,
        canDelete: m.role !== 'owner'
      }));

    const invites = state.invites
      .filter(i => String(i.status || '').toLowerCase() === 'pending')
      .map(i => ({
        key: `invite:${i.id}`,
        type: 'invite',
        id: i.id,
        title: i.inviteName || 'Invite pending',
        subtitle: 'Invite pending',
        code: i.code,
        token: i.token,
        expiresAt: i.expiresAt,
        canDelete: true
      }));

    return [...members, ...invites];
  }

  function isCurrentParent(entry) {
    return entry?.type === 'member' && entry.parentId && state.me && entry.parentId === state.me.id;
  }

  function selectedDevice() {
    return state.devices.find(d => d.id === state.selectedChildId) || null;
  }

  function selectedParentEntry() {
    return parentEntries().find(x => x.key === state.selectedParentKey) || null;
  }

  function pickDayWindow(device) {
    const day = state.selectedDayByDevice[device.id] || device.quietDay || 'mon';
    const fromDays = (device.quietDays && device.quietDays[day]) || null;
    const start = (fromDays && fromDays.start) || '22:00';
    const end = (fromDays && fromDays.end) || '07:00';
    const dailyLimitMinutes = Number((fromDays && fromDays.dailyLimitMinutes) || 0);
    return { day, start, end, dailyLimitMinutes };
  }

  function renderBanner() {
    if (!state.notice) return '';
    return `<div class="banner ${state.noticeType === 'err' ? 'err' : 'ok'}">${escapeHtml(state.notice)}</div>`;
  }

  function renderWelcome(err = '') {
    const queryInviteCode = (new URL(location.href).searchParams.get('inviteCode') || '').trim().toUpperCase();

    app.innerHTML = `
      <div class="screen auth-shell">
        <header class="topbar">
          <div>
            <h1 class="title">SpotChecker</h1>
            <p class="subtitle">Choose device type</p>
          </div>
        </header>

        ${renderBanner()}
        ${err ? `<div class="banner err">${escapeHtml(err)}</div>` : ''}

        <section class="mode-grid">
          <button id="parentModeTile" class="mode-tile" style="background:linear-gradient(135deg, #2d7fff 0%, #2464dd 100%)">
            <span class="avatar-badge">⌂</span>
            <p class="tile-subtitle" style="font-size:38px;color:#fff">Parent phone</p>
          </button>
          <button id="childModeTile" class="mode-tile" style="background:linear-gradient(135deg, #d84adf 0%, #a54de8 100%)">
            <span class="avatar-badge">📱</span>
            <p class="tile-subtitle" style="font-size:38px;color:#fff">Child phone</p>
          </button>
        </section>

        <div class="stack">
          <div class="join-label">Join by invite</div>
          <section class="auth-tile">
            <p class="auth-sub">Enter the 4-character code from the parent.</p>
            <div class="row" style="align-items:center">
              <input id="inviteCode" maxlength="4" class="field code-input" placeholder="ABCD" value="${escapeHtml(queryInviteCode)}" />
              <button id="btnJoin" class="btn primary">Join</button>
            </div>
          </section>

          <details class="help-card">
            <summary class="inline-note" style="cursor:pointer">Connection settings</summary>
            <div class="stack" style="margin-top:10px">
              <input id="apiBase" class="field" value="${escapeHtml(state.apiBase)}" placeholder="https://api.spotchecker.app" />
              <div class="actions-wrap">
                <button id="btnSaveApi" class="btn ghost">Save API Base</button>
              </div>
            </div>
          </details>
        </div>

        <footer class="build">Build ${escapeHtml(WEB_BUILD)}</footer>
      </div>
    `;

    const apiInput = document.getElementById('apiBase');
    const inviteInput = document.getElementById('inviteCode');

    if (inviteInput) {
      inviteInput.addEventListener('input', () => {
        const filtered = String(inviteInput.value || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4);
        if (inviteInput.value !== filtered) inviteInput.value = filtered;
      });
    }

    const saveApi = document.getElementById('btnSaveApi');
    if (saveApi) {
      saveApi.onclick = () => {
        if (apiInput) {
          state.apiBase = String(apiInput.value || '').trim() || state.apiBase;
          localStorage.setItem(API_BASE_KEY, state.apiBase);
        }
        setNotice('API base saved.');
      };
    }

    const signIn = document.getElementById('parentModeTile');
    if (signIn) {
      signIn.onclick = () => {
        if (apiInput) {
          state.apiBase = String(apiInput.value || '').trim() || state.apiBase;
          localStorage.setItem(API_BASE_KEY, state.apiBase);
        }
        const nextPath = `${location.pathname}${location.search}`;
        location.href = `${state.apiBase}/auth/apple/start?next=${encodeURIComponent(nextPath)}`;
      };
    }

    const childTile = document.getElementById('childModeTile');
    if (childTile) {
      childTile.onclick = () => {
        setNotice('Child setup is available in the iOS app.', 'err');
      };
    }

    const join = document.getElementById('btnJoin');
    if (join) {
      join.onclick = () => {
        const code = String(inviteInput?.value || '').trim().toUpperCase();
        if (!/^[A-Z0-9]{4}$/.test(code)) {
          setNotice('Enter a valid 4-character code.', 'err');
          return;
        }
        if (apiInput) {
          state.apiBase = String(apiInput.value || '').trim() || state.apiBase;
          localStorage.setItem(API_BASE_KEY, state.apiBase);
        }
        const u = new URL(location.href);
        u.searchParams.set('inviteCode', code);
        const nextPath = `${u.pathname}${u.search}`;
        location.href = `${state.apiBase}/auth/apple/start?next=${encodeURIComponent(nextPath)}`;
      };
    }
  }

  function renderDeviceTiles() {
    if (!state.devices.length) return '<div class="inline-note">No child devices yet. Use + to create one.</div>';
    return state.devices.map((d, idx) => {
      const selected = d.id === state.selectedChildId;
      const gradient = CHILD_TILE_GRADIENTS[idx % CHILD_TILE_GRADIENTS.length];
      const name = d.name || 'Child device';
      const firstLetter = String(name).trim().charAt(0).toUpperCase() || '?';

      return `
        <button class="tile ${selected ? 'selected' : ''}" data-action="select-child" data-device-id="${escapeHtml(d.id)}" style="background:${escapeHtml(gradient)}">
          <span class="avatar-badge">${escapeHtml(firstLetter)}</span>
          <p class="tile-title">${escapeHtml(name)}</p>
        </button>
      `;
    }).join('');
  }

  function renderParentTiles() {
    const entries = parentEntries();
    if (!entries.length) return '<div class="inline-note">No parent devices or invites yet. Use + to create an invite.</div>';

    return entries.map((p, idx) => {
      const selected = p.key === state.selectedParentKey;
      const gradient = PARENT_TILE_GRADIENTS[idx % PARENT_TILE_GRADIENTS.length];
      const first = String(p.title || '').trim().charAt(0).toUpperCase() || '?';

      return `
        <button class="tile ${selected ? 'selected' : ''}" data-action="select-parent" data-parent-key="${escapeHtml(p.key)}" style="background:${escapeHtml(gradient)}">
          <span class="avatar-badge">${escapeHtml(first)}</span>
          <div>
            <p class="tile-title" style="font-size:34px">${escapeHtml(p.title)}</p>
            <p class="tile-subtitle" style="font-size:26px">${escapeHtml(p.subtitle)}</p>
          </div>
        </button>
      `;
    }).join('');
  }

  function scheduleSummary(device) {
    const out = pickDayWindow(device);
    return `${DAY_LABEL[out.day]} ${out.start} - ${out.end}`;
  }

  function renderChildDetail(device) {
    const dayWindow = pickDayWindow(device);
    const pending = state.pendingByDevice[device.id] || null;
    const events = state.eventsByDevice[device.id] || [];

    const daily = device.dailyLimit;
    const dailySummary = (daily && daily.limitMinutes != null)
      ? `${minsToHm(daily.usedMinutes || 0)} / ${minsToHm(daily.limitMinutes)} used (${minsToHm(daily.remainingMinutes || 0)} left)`
      : 'Not set';

    const canDelete = String(state.household?.role || '').toLowerCase() === 'owner';

    return `
      <section class="panel stack">
        <div class="row spread">
          <div>
            <h2>${escapeHtml(device.name || 'Child device')}</h2>
            <p class="panel-sub">${escapeHtml(device.statusMessage || 'No status yet.')}</p>
          </div>
          <span class="pill ${device.enforce ? 'ok' : 'warn'}">${device.enforce ? 'Protection On' : 'Protection Off'}</span>
        </div>

        <div class="actions-wrap">
          <button class="btn ghost" data-action="open-pairing" data-device-id="${escapeHtml(device.id)}">View Pairing Code</button>
          <button class="btn ghost" data-action="refresh-events" data-device-id="${escapeHtml(device.id)}">Refresh Activity</button>
          ${canDelete ? `<button class="btn danger" data-action="delete-child" data-device-id="${escapeHtml(device.id)}">Delete Child</button>` : ''}
        </div>

        <div class="rules">
          <h3>Rules</h3>

          <div class="toggle-row">
            <div>
              <label for="ruleLockApps">Lock Apps</label>
              <div class="helper">Block certain apps. Set list on child phone.</div>
            </div>
            <input id="ruleLockApps" class="toggle" type="checkbox" ${device.actions?.activateProtection ? 'checked' : ''} />
          </div>

          <div class="toggle-row">
            <div><label for="ruleHotspot">Turn Hotspot off</label></div>
            <input id="ruleHotspot" class="toggle" type="checkbox" ${device.actions?.setHotspotOff ? 'checked' : ''} />
          </div>

          <div class="toggle-row">
            <div><label for="ruleWifi">Turn Wi-Fi Off</label></div>
            <input id="ruleWifi" class="toggle" type="checkbox" ${device.actions?.setWifiOff ? 'checked' : ''} />
          </div>

          <div class="toggle-row">
            <div><label for="ruleData">Turn Mobile Data Off</label></div>
            <input id="ruleData" class="toggle" type="checkbox" ${device.actions?.setMobileDataOff ? 'checked' : ''} />
          </div>
        </div>

        <div class="rules">
          <div class="row spread">
            <h3>Rules Enforcement Schedule</h3>
            <span class="pill">${escapeHtml(scheduleSummary(device))}</span>
          </div>

          <div class="chip-row">
            ${DAY_KEYS.map(key => `<button class="chip ${key === dayWindow.day ? 'active' : ''}" data-action="set-day" data-device-id="${escapeHtml(device.id)}" data-day="${key}">${DAY_LABEL[key]}</button>`).join('')}
          </div>

          <div class="time-grid">
            <div>
              <p class="kicker">Start</p>
              <input id="scheduleStart" class="time-field" type="time" value="${escapeHtml(dayWindow.start)}" />
            </div>
            <div>
              <p class="kicker">End</p>
              <input id="scheduleEnd" class="time-field" type="time" value="${escapeHtml(dayWindow.end)}" />
            </div>
            <div>
              <p class="kicker">Total daily limit</p>
              <select id="dailyLimit" class="select">
                <option value="0" ${dayWindow.dailyLimitMinutes === 0 ? 'selected' : ''}>Off</option>
                ${Array.from({ length: 32 }, (_, i) => (i + 1) * 15).map(m => `<option value="${m}" ${dayWindow.dailyLimitMinutes === m ? 'selected' : ''}>${minsToHm(m)}</option>`).join('')}
              </select>
            </div>
          </div>

          <div class="row spread">
            <span class="inline-note">Daily usage: ${escapeHtml(dailySummary)}</span>
            <div class="actions-wrap">
              <button class="btn ghost" data-action="copy-day" data-device-id="${escapeHtml(device.id)}">Copy to all days</button>
              <button class="btn primary" data-action="save-device" data-device-id="${escapeHtml(device.id)}">Save Rules</button>
            </div>
          </div>
        </div>

        <div class="rules">
          <h3>Extra Time</h3>
          <p class="panel-sub">Temporarily disable enforcement for this child.</p>

          ${pending ? `
            <div class="help-card">
              <div class="row spread">
                <div>
                  <strong>You have a pending request</strong>
                  <p class="panel-sub">Requested ${minsToHm(pending.requestedMinutes)} at ${formatDateTime(pending.requestedAt)}</p>
                </div>
                <span class="pill warn">Pending</span>
              </div>
              <div class="actions-wrap" style="margin-top:10px">
                <button class="btn primary" data-action="approve-request" data-request-id="${escapeHtml(pending.id)}" data-device-id="${escapeHtml(device.id)}">Approve</button>
                <button class="btn danger" data-action="deny-request" data-request-id="${escapeHtml(pending.id)}" data-device-id="${escapeHtml(device.id)}">Deny</button>
              </div>
            </div>
          ` : '<div class="inline-note">No pending request.</div>'}

          <div class="form-row">
            <label for="extraMinutes" class="kicker" style="margin:0">Amount</label>
            <select id="extraMinutes" class="select" style="max-width:180px">
              ${Array.from({ length: 49 }, (_, i) => i * 5).map(m => `<option value="${m}">${minsToHm(m)}</option>`).join('')}
            </select>
          </div>

          <div class="actions-wrap">
            <button class="btn primary" data-action="apply-extra" data-device-id="${escapeHtml(device.id)}">Apply extra time</button>
          </div>

          <div class="inline-note">
            ${device.activeExtraTime?.endsAt ? `Extra time active until ${formatDateTime(device.activeExtraTime.endsAt)}.` : 'No active extra time.'}
          </div>
        </div>

        <div class="rules">
          <div class="row spread">
            <h3>Recent activity</h3>
            <span class="pill">${events.length} events</span>
          </div>
          <ul class="activity-list">
            ${events.length ? events.slice(0, 12).map(ev => `
              <li class="activity-row">
                <span class="activity-time">${escapeHtml(formatDateTime(ev.ts))}</span>
                <span class="activity-label">${escapeHtml(eventLabel(ev.trigger))}</span>
              </li>
            `).join('') : '<li class="inline-note">No activity yet.</li>'}
          </ul>
        </div>
      </section>
    `;
  }

  function renderParentDetail(entry) {
    const current = isCurrentParent(entry);
    const isOwner = String(state.household?.role || '').toLowerCase() === 'owner';

    const prefKey = entry.type === 'member' ? entry.parentId : `invite:${entry.id}`;
    const prefs = state.notifPrefs[prefKey] || { extraTime: true, tamper: true };

    return `
      <section class="panel stack">
        <div class="row spread">
          <div>
            <h2>${escapeHtml(entry.title)}</h2>
            <p class="panel-sub">${escapeHtml(entry.subtitle)}</p>
          </div>
          <span class="pill">${entry.type === 'invite' ? 'Invite' : 'Parent'}</span>
        </div>

        <div class="rules">
          <h3>${entry.type === 'invite' ? 'Invite Settings' : 'Profile'}</h3>

          <div class="form-row">
            <input id="renameInput" class="field" value="${escapeHtml(entry.title)}" placeholder="Name" ${(!current && entry.type !== 'invite') ? 'disabled' : ''} />
            <button class="btn primary" data-action="save-parent-name" data-parent-key="${escapeHtml(entry.key)}" ${(!current && entry.type !== 'invite') ? 'disabled' : ''}>Save name</button>
          </div>

          ${entry.type === 'invite' ? `
            <div class="stack">
              <div class="inline-note">Invite code</div>
              <div class="pill" style="font-size:18px;letter-spacing:0.12em">${escapeHtml(entry.code || '----')}</div>
              <div class="inline-note">Expires ${formatDateTime(entry.expiresAt)}</div>
            </div>
          ` : ''}
        </div>

        <div class="rules">
          <h3>Notification Settings</h3>
          ${!current && entry.type === 'member' ? '<p class="panel-sub">Visible here, but only this parent can change their own settings.</p>' : ''}

          <div class="toggle-row">
            <div><label for="notifyExtra">Extra time requests</label></div>
            <input id="notifyExtra" class="toggle" type="checkbox" ${prefs.extraTime ? 'checked' : ''} ${(!current && entry.type === 'member') ? 'disabled' : ''} />
          </div>
          <div class="toggle-row">
            <div><label for="notifyTamper">Tamper alerts</label></div>
            <input id="notifyTamper" class="toggle" type="checkbox" ${prefs.tamper ? 'checked' : ''} ${(!current && entry.type === 'member') ? 'disabled' : ''} />
          </div>
        </div>

        <div class="actions-wrap">
          ${entry.type === 'invite' ? `<button class="btn danger" data-action="delete-parent-entry" data-parent-key="${escapeHtml(entry.key)}">Delete Invite</button>` : ''}
          ${entry.type === 'member' && entry.canDelete && isOwner ? `<button class="btn danger" data-action="delete-parent-entry" data-parent-key="${escapeHtml(entry.key)}">Delete Parent</button>` : ''}
        </div>
      </section>
    `;
  }

  function renderDetailPanel() {
    const device = selectedDevice();
    if (device) return renderChildDetail(device);

    const parentEntry = selectedParentEntry();
    if (parentEntry) return renderParentDetail(parentEntry);

    return `
      <section class="detail-empty">
        <div>
          <p>Select a child or parent tile to open settings.</p>
          <p class="inline-note">This mirrors the iOS edit flow while keeping desktop-friendly spacing.</p>
        </div>
      </section>
    `;
  }

  function renderDashboard() {
    const who = state.me?.displayName || state.me?.email || 'Parent';

    app.innerHTML = `
      <div class="screen">
        <header class="topbar">
          <div>
            <h1 class="title">SpotChecker</h1>
            <div class="meta-row">
              <span class="pill">${escapeHtml(who)}</span>
              <span class="pill">${escapeHtml(state.household?.role || '')}</span>
            </div>
          </div>
          <div class="actions-wrap">
            <button class="btn ghost" id="refreshDash">Refresh</button>
            <button class="btn danger" id="signOut">Sign out</button>
          </div>
        </header>

        ${renderBanner()}

        <div class="main-grid">
          <div class="stack">
            <section class="section-card tile-section">
              <div class="section-title-row">
                <h2 class="section-title">Child Devices</h2>
              <button class="icon-plus" id="addChild" aria-label="Add child">+</button>
            </div>
            <div id="childTiles" class="tiles-grid">${renderDeviceTiles()}</div>
          </section>

            <section class="section-card tile-section">
              <div class="section-title-row">
                <h2 class="section-title">Parent Devices</h2>
                <button class="icon-plus" id="addParentInvite" aria-label="Add parent invite">+</button>
              </div>
              <div id="parentTiles" class="tiles-grid">${renderParentTiles()}</div>
            </section>

            <section class="panel stack">
              <h3>Quick Actions</h3>
              <div class="form-row">
                <input id="newChildName" class="field" placeholder="Enter your child's name" />
                <button class="btn primary" id="createChildBtn">Add Child</button>
              </div>
              <div class="form-row">
                <input id="inviteName" class="field" placeholder="Invite name" />
                <button class="btn primary" id="createInviteBtn">Create Invite</button>
              </div>
              <div class="form-row">
                <input id="joinCode" maxlength="4" class="field code-input" placeholder="ABCD" />
                <button class="btn ghost" id="joinCodeBtn">Join by code</button>
              </div>
              <div class="form-row">
                <input id="apiBase" class="field" value="${escapeHtml(state.apiBase)}" />
                <button class="btn ghost" id="saveApiBtn">Save API Base</button>
              </div>
            </section>
          </div>

          <div id="detailPanel">${renderDetailPanel()}</div>
        </div>

        <footer class="build">Build ${escapeHtml(WEB_BUILD)}</footer>
      </div>
    `;

    bindStaticHandlers();
  }

  function bindStaticHandlers() {
    const refresh = document.getElementById('refreshDash');
    if (refresh) refresh.onclick = () => loadAll('Updated.');

    const signOut = document.getElementById('signOut');
    if (signOut) {
      signOut.onclick = () => {
        state.sessionToken = '';
        localStorage.removeItem(SESSION_KEY);
        state.notice = null;
        renderWelcome();
      };
    }

    const saveApi = document.getElementById('saveApiBtn');
    if (saveApi) {
      saveApi.onclick = () => {
        const value = String(document.getElementById('apiBase')?.value || '').trim();
        if (!value) return;
        state.apiBase = value;
        localStorage.setItem(API_BASE_KEY, value);
        setNotice('API base saved.');
      };
    }

    const joinCodeInput = document.getElementById('joinCode');
    if (joinCodeInput) {
      joinCodeInput.oninput = () => {
        const filtered = String(joinCodeInput.value || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4);
        if (joinCodeInput.value !== filtered) joinCodeInput.value = filtered;
      };
    }

    const addChild = document.getElementById('addChild');
    if (addChild) addChild.onclick = () => document.getElementById('newChildName')?.focus();

    const addParentInvite = document.getElementById('addParentInvite');
    if (addParentInvite) addParentInvite.onclick = () => document.getElementById('inviteName')?.focus();

    const createChild = document.getElementById('createChildBtn');
    if (createChild) {
      createChild.onclick = async () => {
        const name = String(document.getElementById('newChildName')?.value || '').trim();
        if (!name) {
          setNotice('Enter a child name first.', 'err');
          return;
        }
        try {
          await api('/api/devices', { method: 'POST', body: JSON.stringify({ name }) });
          await loadAll('Child added.');
        } catch (e) {
          setNotice(`Couldn’t add child: ${friendlyError(e)}`, 'err');
        }
      };
    }

    const createInvite = document.getElementById('createInviteBtn');
    if (createInvite) {
      createInvite.onclick = async () => {
        const inviteName = String(document.getElementById('inviteName')?.value || '').trim();
        if (!inviteName) {
          setNotice('Invite name is required.', 'err');
          return;
        }
        try {
          await api('/api/household/invites', { method: 'POST', body: JSON.stringify({ inviteName }) });
          await loadAll('Invite created.');
        } catch (e) {
          setNotice(`Couldn’t create invite: ${friendlyError(e)}`, 'err');
        }
      };
    }

    const joinCode = document.getElementById('joinCodeBtn');
    if (joinCode) {
      joinCode.onclick = async () => {
        const code = String(document.getElementById('joinCode')?.value || '').trim().toUpperCase();
        if (!/^[A-Z0-9]{4}$/.test(code)) {
          setNotice('Invite code must be 4 characters.', 'err');
          return;
        }
        try {
          await api('/api/household/invite-code/accept', { method: 'POST', body: JSON.stringify({ code }) });
          await loadAll('Joined household.');
        } catch (e) {
          setNotice(`Join failed: ${friendlyError(e)}`, 'err');
        }
      };
    }

    app.querySelectorAll('[data-action="select-child"]').forEach(el => {
      el.addEventListener('click', async () => {
        const id = el.getAttribute('data-device-id');
        if (!id) return;
        state.selectedChildId = id;
        state.selectedParentKey = null;
        renderDashboard();
        await refreshDeviceEvents(id);
        await refreshPendingForDevice(id);
        renderDashboard();
      });
    });

    app.querySelectorAll('[data-action="select-parent"]').forEach(el => {
      el.addEventListener('click', () => {
        const key = el.getAttribute('data-parent-key');
        if (!key) return;
        state.selectedParentKey = key;
        state.selectedChildId = null;
        renderDashboard();
      });
    });

    app.querySelectorAll('[data-action="set-day"]').forEach(el => {
      el.addEventListener('click', () => {
        const id = el.getAttribute('data-device-id');
        const day = el.getAttribute('data-day');
        if (!id || !day) return;
        state.selectedDayByDevice[id] = day;
        renderDashboard();
      });
    });

    app.querySelectorAll('[data-action="copy-day"]').forEach(el => {
      el.addEventListener('click', () => {
        const id = el.getAttribute('data-device-id');
        const d = state.devices.find(x => x.id === id);
        if (!d) return;
        const selectedDay = state.selectedDayByDevice[id] || d.quietDay || 'mon';
        const start = String(document.getElementById('scheduleStart')?.value || '22:00');
        const end = String(document.getElementById('scheduleEnd')?.value || '07:00');
        const dailyLimitMinutes = Number(document.getElementById('dailyLimit')?.value || 0);

        const quietDays = { ...(d.quietDays || {}) };
        DAY_KEYS.forEach(day => {
          quietDays[day] = day === selectedDay
            ? { start, end, dailyLimitMinutes }
            : { start, end, dailyLimitMinutes };
        });
        d.quietDays = quietDays;
        setNotice('Copied to all days.');
        renderDashboard();
      });
    });

    app.querySelectorAll('[data-action="save-device"]').forEach(el => {
      el.addEventListener('click', async () => {
        const id = el.getAttribute('data-device-id');
        const device = state.devices.find(x => x.id === id);
        if (!device) return;

        const activateProtection = !!document.getElementById('ruleLockApps')?.checked;
        const setHotspotOff = !!document.getElementById('ruleHotspot')?.checked;
        const setWifiOff = !!document.getElementById('ruleWifi')?.checked;
        const setMobileDataOff = !!document.getElementById('ruleData')?.checked;
        const start = String(document.getElementById('scheduleStart')?.value || '22:00');
        const end = String(document.getElementById('scheduleEnd')?.value || '07:00');
        const dailyLimitMinutes = Number(document.getElementById('dailyLimit')?.value || 0);

        const day = state.selectedDayByDevice[id] || device.quietDay || 'mon';

        const existing = device.quietDays || {};
        const quietDays = {};
        DAY_KEYS.forEach(k => {
          const src = existing[k] || { start: '22:00', end: '07:00', dailyLimitMinutes: 0 };
          quietDays[k] = {
            start: src.start || '22:00',
            end: src.end || '07:00',
            dailyLimitMinutes: Number(src.dailyLimitMinutes || 0)
          };
        });
        quietDays[day] = { start, end, dailyLimitMinutes };

        try {
          await api(`/api/devices/${id}/policy`, {
            method: 'PATCH',
            body: JSON.stringify({
              activateProtection,
              setHotspotOff,
              setWifiOff,
              setMobileDataOff,
              quietDays,
              tz: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Europe/Paris'
            })
          });
          await loadAll('Saved.');
          state.selectedChildId = id;
          renderDashboard();
        } catch (e) {
          setNotice(`Couldn’t save rules: ${friendlyError(e)}`, 'err');
        }
      });
    });

    app.querySelectorAll('[data-action="open-pairing"]').forEach(el => {
      el.addEventListener('click', async () => {
        const id = el.getAttribute('data-device-id');
        if (!id) return;
        try {
          const out = await api(`/api/devices/${id}/pairing-code`, { method: 'POST', body: JSON.stringify({ ttlMinutes: 10 }) });
          setNotice(`Pairing code ${out.code} (expires ${formatDateTime(out.expiresAt)}).`);
        } catch (e) {
          setNotice(`Couldn’t create pairing code: ${friendlyError(e)}`, 'err');
        }
      });
    });

    app.querySelectorAll('[data-action="refresh-events"]').forEach(el => {
      el.addEventListener('click', async () => {
        const id = el.getAttribute('data-device-id');
        if (!id) return;
        await refreshDeviceEvents(id);
        renderDashboard();
        setNotice('Updated.');
      });
    });

    app.querySelectorAll('[data-action="delete-child"]').forEach(el => {
      el.addEventListener('click', async () => {
        const id = el.getAttribute('data-device-id');
        if (!id) return;
        if (!window.confirm('Delete this child device?')) return;
        try {
          await api(`/api/devices/${id}`, { method: 'DELETE' });
          if (state.selectedChildId === id) state.selectedChildId = null;
          await loadAll('Child deleted.');
        } catch (e) {
          setNotice(`Couldn’t delete child: ${friendlyError(e)}`, 'err');
        }
      });
    });

    app.querySelectorAll('[data-action="apply-extra"]').forEach(el => {
      el.addEventListener('click', async () => {
        const id = el.getAttribute('data-device-id');
        if (!id) return;
        const minutes = Number(document.getElementById('extraMinutes')?.value || 0);
        try {
          await api(`/api/devices/${id}/extra-time/grant`, { method: 'POST', body: JSON.stringify({ minutes }) });
          await loadAll(minutes > 0 ? 'Extra time applied.' : 'Extra time cleared.');
          state.selectedChildId = id;
          await refreshDeviceEvents(id);
          renderDashboard();
        } catch (e) {
          setNotice(`Couldn’t apply extra time: ${friendlyError(e)}`, 'err');
        }
      });
    });

    app.querySelectorAll('[data-action="approve-request"]').forEach(el => {
      el.addEventListener('click', async () => {
        const requestId = el.getAttribute('data-request-id');
        const deviceId = el.getAttribute('data-device-id');
        const grantedMinutes = Number(document.getElementById('extraMinutes')?.value || 0);
        if (!requestId || !deviceId) return;
        try {
          await api(`/api/extra-time/requests/${requestId}/decision`, {
            method: 'POST',
            body: JSON.stringify({ decision: 'approve', grantedMinutes })
          });
          await loadAll('Request approved.');
          state.selectedChildId = deviceId;
          await refreshDeviceEvents(deviceId);
          renderDashboard();
        } catch (e) {
          setNotice(`Couldn’t approve request: ${friendlyError(e)}`, 'err');
        }
      });
    });

    app.querySelectorAll('[data-action="deny-request"]').forEach(el => {
      el.addEventListener('click', async () => {
        const requestId = el.getAttribute('data-request-id');
        const deviceId = el.getAttribute('data-device-id');
        if (!requestId || !deviceId) return;
        try {
          await api(`/api/extra-time/requests/${requestId}/decision`, {
            method: 'POST',
            body: JSON.stringify({ decision: 'deny' })
          });
          await loadAll('Request denied.');
          state.selectedChildId = deviceId;
          await refreshDeviceEvents(deviceId);
          renderDashboard();
        } catch (e) {
          setNotice(`Couldn’t deny request: ${friendlyError(e)}`, 'err');
        }
      });
    });

    app.querySelectorAll('[data-action="save-parent-name"]').forEach(el => {
      el.addEventListener('click', async () => {
        const key = el.getAttribute('data-parent-key');
        const entry = parentEntries().find(x => x.key === key);
        const name = String(document.getElementById('renameInput')?.value || '').trim();
        if (!entry || !name) return;
        try {
          if (entry.type === 'invite') {
            await api(`/api/household/invites/${entry.id}`, { method: 'PATCH', body: JSON.stringify({ inviteName: name }) });
          } else if (isCurrentParent(entry)) {
            await api('/api/me/profile', { method: 'PATCH', body: JSON.stringify({ displayName: name }) });
          }
          await loadAll('Name updated.');
          state.selectedParentKey = key;
          renderDashboard();
        } catch (e) {
          setNotice(`Couldn’t update name: ${friendlyError(e)}`, 'err');
        }
      });
    });

    app.querySelectorAll('[data-action="delete-parent-entry"]').forEach(el => {
      el.addEventListener('click', async () => {
        const key = el.getAttribute('data-parent-key');
        const entry = parentEntries().find(x => x.key === key);
        if (!entry) return;
        const prompt = entry.type === 'invite' ? 'Delete this invite?' : 'Delete this parent from household?';
        if (!window.confirm(prompt)) return;

        try {
          if (entry.type === 'invite') {
            await api(`/api/household/invites/${entry.id}`, { method: 'DELETE' });
          } else {
            await api(`/api/household/members/${entry.id}`, { method: 'DELETE' });
          }
          if (state.selectedParentKey === key) state.selectedParentKey = null;
          await loadAll('Deleted.');
        } catch (e) {
          setNotice(`Couldn’t delete: ${friendlyError(e)}`, 'err');
        }
      });
    });

    const notifyExtra = document.getElementById('notifyExtra');
    const notifyTamper = document.getElementById('notifyTamper');
    if (notifyExtra || notifyTamper) {
      const entry = selectedParentEntry();
      if (entry) {
        const prefKey = entry.type === 'member' ? entry.parentId : `invite:${entry.id}`;

        if (notifyExtra) {
          notifyExtra.onchange = () => {
            if (!state.notifPrefs[prefKey]) state.notifPrefs[prefKey] = { extraTime: true, tamper: true };
            state.notifPrefs[prefKey].extraTime = !!notifyExtra.checked;
            saveNotificationPrefs();
          };
        }

        if (notifyTamper) {
          notifyTamper.onchange = () => {
            if (!state.notifPrefs[prefKey]) state.notifPrefs[prefKey] = { extraTime: true, tamper: true };
            state.notifPrefs[prefKey].tamper = !!notifyTamper.checked;
            saveNotificationPrefs();
          };
        }
      }
    }
  }

  async function refreshDeviceEvents(deviceId) {
    try {
      const out = await api(`/api/devices/${deviceId}/events`);
      state.eventsByDevice[deviceId] = Array.isArray(out.events) ? out.events : [];
    } catch {
      state.eventsByDevice[deviceId] = [];
    }
  }

  async function refreshPendingForDevice(deviceId) {
    try {
      const out = await api(`/api/extra-time/requests?status=pending&deviceId=${encodeURIComponent(deviceId)}`);
      const list = Array.isArray(out.requests) ? out.requests : [];
      state.pendingByDevice[deviceId] = list.length ? list[0] : null;
    } catch {
      state.pendingByDevice[deviceId] = null;
    }
  }

  async function processInviteFromUrl() {
    const url = new URL(location.href);

    const code = String(url.searchParams.get('inviteCode') || '').trim().toUpperCase();
    if (/^[A-Z0-9]{4}$/.test(code)) {
      await api('/api/household/invite-code/accept', { method: 'POST', body: JSON.stringify({ code }) });
      url.searchParams.delete('inviteCode');
      history.replaceState(null, '', `${url.pathname}${url.search}`);
      state.notice = 'Invite joined.';
      state.noticeType = 'ok';
      return;
    }

    const token = String(url.searchParams.get('token') || '').trim();
    if (token) {
      await api(`/api/household/invites/${encodeURIComponent(token)}/accept`, { method: 'POST' });
      url.searchParams.delete('token');
      history.replaceState(null, '', `${url.pathname}${url.search}`);
      state.notice = 'Invite joined.';
      state.noticeType = 'ok';
    }
  }

  async function loadAll(info = '') {
    if (state.busy) return;
    state.busy = true;

    try {
      await processInviteFromUrl();

      const [me, members, invites, dash, pending] = await Promise.all([
        api('/api/me'),
        api('/api/household/members'),
        api('/api/household/invites'),
        api('/api/dashboard'),
        api('/api/extra-time/requests?status=pending')
      ]);

      state.me = me.parent;
      state.household = me.household;
      state.members = members.members || [];
      state.invites = invites.invites || [];
      state.devices = dash.devices || [];

      const pendingMap = {};
      (pending.requests || []).forEach(req => {
        if (!pendingMap[req.deviceId]) pendingMap[req.deviceId] = req;
      });
      state.pendingByDevice = pendingMap;

      if (!state.selectedChildId && state.devices.length) state.selectedChildId = state.devices[0].id;
      if (state.selectedChildId && !state.devices.some(d => d.id === state.selectedChildId)) state.selectedChildId = state.devices[0]?.id || null;

      if (state.selectedParentKey && !parentEntries().some(x => x.key === state.selectedParentKey)) state.selectedParentKey = null;

      if (state.selectedChildId && !state.eventsByDevice[state.selectedChildId]) {
        await refreshDeviceEvents(state.selectedChildId);
      }

      if (info) {
        state.notice = info;
        state.noticeType = 'ok';
      }

      renderDashboard();
    } catch (e) {
      const msg = friendlyError(e);
      if (msg.toLowerCase().includes('sign in again')) {
        state.sessionToken = '';
        localStorage.removeItem(SESSION_KEY);
        renderWelcome(msg);
      } else {
        renderWelcome(`Load failed: ${msg}`);
      }
    } finally {
      state.busy = false;
    }
  }

  function render() {
    if (!state.sessionToken) renderWelcome();
    else renderDashboard();
  }

  async function boot() {
    parseHashSession();
    if (!state.sessionToken) {
      renderWelcome();
      return;
    }
    await loadAll();
  }

  boot().catch(err => {
    renderWelcome(`Load failed: ${friendlyError(err)}`);
  });
})();
