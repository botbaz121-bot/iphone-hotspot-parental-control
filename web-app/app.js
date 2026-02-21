(() => {
  const WEB_BUILD = '0.1.59-webdebug-20260221';
  const API_BASE_KEY = 'spotchecker.web.apiBase';
  const SESSION_KEY = 'spotchecker.web.sessionToken';

  const state = {
    apiBase: localStorage.getItem(API_BASE_KEY) || 'https://api.spotchecker.app',
    sessionToken: localStorage.getItem(SESSION_KEY) || '',
    me: null,
    household: null,
    members: [],
    invites: [],
    devices: [],
    selectedDayByDevice: {},
    debugLines: []
  };

  const app = document.getElementById('app');

  function addDebug(message, extra) {
    const ts = new Date().toISOString();
    const suffix = extra ? ` ${JSON.stringify(extra)}` : '';
    state.debugLines.push(`[${ts}] ${message}${suffix}`);
    if (state.debugLines.length > 120) state.debugLines.shift();
    try { console.log('[web-debug]', message, extra || ''); } catch {}
  }

  window.addEventListener('error', (ev) => {
    addDebug('window.error', { message: ev.message, stack: ev.error?.stack || '' });
  });
  window.addEventListener('unhandledrejection', (ev) => {
    const reason = ev.reason && typeof ev.reason === 'object'
      ? { message: ev.reason.message || String(ev.reason), stack: ev.reason.stack || '' }
      : { message: String(ev.reason || '') };
    addDebug('window.unhandledrejection', reason);
  });

  function parseHashSession() {
    const raw = (location.hash || '').replace(/^#/, '');
    if (!raw) return;
    const p = new URLSearchParams(raw);
    const tok = (p.get('sessionToken') || '').trim();
    if (tok) {
      state.sessionToken = tok;
      localStorage.setItem(SESSION_KEY, tok);
      history.replaceState(null, '', location.pathname + location.search);
    }
  }

  function escapeHtml(v) {
    return String(v ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
  }

  async function api(path, opts = {}) {
    const headers = {
      'Content-Type': 'application/json',
      ...(opts.headers || {})
    };
    if (state.sessionToken) headers.Authorization = `Bearer ${state.sessionToken}`;

    const res = await fetch(state.apiBase + path, { ...opts, headers });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text }; }
    if (!res.ok) {
      const msg = data?.error || data?.detail || `${res.status} error`;
      throw new Error(msg);
    }
    return data;
  }

  function renderAuthOnly(err = '') {
    const debugText = state.debugLines.join('\n');
    const urlCode = (new URL(location.href).searchParams.get('inviteCode') || '').trim().toUpperCase();
    app.innerHTML = `
      <div class="top">
        <h1>SpotChecker Web Parent</h1>
      </div>
      <div class="grid">
        <section class="card half">
          <h2>Sign In</h2>
          <p class="muted">Use Apple sign in to access household, invites, and child controls.</p>
          <p class="muted">Build: ${escapeHtml(WEB_BUILD)}</p>
          ${err ? `<p class="err">${escapeHtml(err)}</p>` : ''}
          <div class="col">
            <label class="muted">API Base</label>
            <input id="apiBase" value="${escapeHtml(state.apiBase)}" placeholder="https://api.spotchecker.app" />
            <div class="row">
              <button id="saveApi" class="ghost">Save API Base</button>
              <button id="signIn" class="primary">Sign in with Apple</button>
            </div>
          </div>
          <hr class="sep" />
          <div class="col">
            <label class="muted">Invite code</label>
            <input id="preAuthInviteCode" maxlength="4" placeholder="ABCD" value="${escapeHtml(urlCode)}" />
            <p class="muted">Enter code first, then continue with Apple sign in.</p>
            <div class="row">
              <button id="signInWithCode" class="primary">Join with code</button>
            </div>
          </div>
          ${debugText ? `<pre class="code" style="margin-top:10px;white-space:pre-wrap;max-height:280px;overflow:auto">${escapeHtml(debugText)}</pre>` : ''}
        </section>
      </div>
    `;

    document.getElementById('saveApi').onclick = () => {
      state.apiBase = document.getElementById('apiBase').value.trim();
      localStorage.setItem(API_BASE_KEY, state.apiBase);
      renderAuthOnly();
    };

    document.getElementById('signIn').onclick = () => {
      state.apiBase = document.getElementById('apiBase').value.trim();
      localStorage.setItem(API_BASE_KEY, state.apiBase);
      const nextPath = `${location.pathname}${location.search}`;
      location.href = `${state.apiBase}/auth/apple/start?next=${encodeURIComponent(nextPath)}`;
    };

    document.getElementById('signInWithCode').onclick = () => {
      state.apiBase = document.getElementById('apiBase').value.trim();
      localStorage.setItem(API_BASE_KEY, state.apiBase);
      const code = (document.getElementById('preAuthInviteCode').value || '').trim().toUpperCase();
      if (!/^[A-Z0-9]{4}$/.test(code)) {
        renderAuthOnly('Please enter a valid 4-character invite code.');
        return;
      }
      const u = new URL(location.href);
      u.searchParams.set('inviteCode', code);
      const nextPath = `${u.pathname}${u.search}`;
      location.href = `${state.apiBase}/auth/apple/start?next=${encodeURIComponent(nextPath)}`;
    };
  }

  function inviteAcceptCodeFromUrl() {
    const u = new URL(location.href);
    return (u.searchParams.get('inviteCode') || '').trim().toUpperCase();
  }

  function clearInviteCodeFromUrl() {
    const u = new URL(location.href);
    if (!u.searchParams.has('inviteCode')) return;
    u.searchParams.delete('inviteCode');
    history.replaceState(null, '', `${u.pathname}${u.search}`);
  }

  function minsToHm(mins) {
    const m = Number(mins || 0);
    const h = Math.floor(m / 60);
    const r = m % 60;
    if (h <= 0) return `${r}m`;
    if (r === 0) return `${h}h`;
    return `${h}h ${r}m`;
  }

  function buildInviteList() {
    if (!state.invites.length) return '<p class="muted">No invites yet.</p>';
    return state.invites.map(i => {
      return `
        <div class="invite-card device-card">
          <div class="row" style="justify-content:space-between">
            <strong>${escapeHtml(i.inviteName || i.email || 'Manual invite')}</strong>
            <span class="badge">${escapeHtml(i.status)}</span>
          </div>
          <div class="muted">Expires: ${new Date(i.expiresAt).toLocaleString()}</div>
          <div class="kv"><div class="muted">Code</div><div class="code">${escapeHtml(i.code)}</div></div>
        </div>
      `;
    }).join('');
  }

  function buildMembersList() {
    if (!state.members.length) return '<p class="muted">No household members.</p>';
    return state.members.map(m => `
      <div class="row" style="justify-content:space-between; border:1px solid var(--line); border-radius:10px; padding:8px 10px;">
        <div>
          <strong>${escapeHtml(m.displayName || m.email || m.parentId)}</strong>
          <div class="muted">${escapeHtml(m.parentId)}</div>
        </div>
        <div class="row">
          <span class="badge">${escapeHtml(m.role)}</span>
          <span class="badge">${escapeHtml(m.status)}</span>
        </div>
      </div>
    `).join('');
  }

  function pickCurrentDayWindow(device) {
    const day = state.selectedDayByDevice[device.id] || device.quietDay || 'mon';
    const w = (device.quietDays && device.quietDays[day]) || { start: '22:00', end: '07:00', dailyLimitMinutes: 0 };
    return { day, window: w };
  }

  function buildDeviceCards() {
    if (!state.devices.length) return '<p class="muted">No child devices yet.</p>';

    return state.devices.map(d => {
      const canDelete = state.household?.role === 'owner';
      const { day, window } = pickCurrentDayWindow(d);
      const daily = d.dailyLimit;

      return `
        <article class="device-card" data-device-id="${escapeHtml(d.id)}">
          <div class="device-head">
            <div>
              <h3>${escapeHtml(d.name)}</h3>
              <div class="muted">${escapeHtml(d.device_token || '')}</div>
            </div>
            <div class="row">
              <span class="badge">${d.enforce ? 'Enforced now' : 'Not enforced now'}</span>
              <button class="pairBtn">Pairing code</button>
              ${canDelete ? '<button class="danger delBtn">Delete child</button>' : ''}
            </div>
          </div>

          <p class="muted" style="margin-top:8px">${escapeHtml(d.statusMessage || '')}</p>

          <div class="kv"><label>Lock Apps</label><input type="checkbox" class="f-activateProtection" ${d.actions?.activateProtection ? 'checked' : ''} /></div>
          <div class="kv"><label>Turn Hotspot Off</label><input type="checkbox" class="f-setHotspotOff" ${d.actions?.setHotspotOff ? 'checked' : ''} /></div>
          <div class="kv"><label>Turn Wi-Fi Off</label><input type="checkbox" class="f-setWifiOff" ${d.actions?.setWifiOff ? 'checked' : ''} /></div>
          <div class="kv"><label>Turn Mobile Data Off</label><input type="checkbox" class="f-setMobileDataOff" ${d.actions?.setMobileDataOff ? 'checked' : ''} /></div>

          <hr class="sep" />

          <div class="row">
            <label class="muted">Day</label>
            <select class="f-day">
              ${['sun','mon','tue','wed','thu','fri','sat'].map(k => `<option value="${k}" ${k === day ? 'selected' : ''}>${k.toUpperCase()}</option>`).join('')}
            </select>
            <label class="muted">Start</label>
            <input type="time" class="f-start" value="${escapeHtml(window.start || '22:00')}" />
            <label class="muted">End</label>
            <input type="time" class="f-end" value="${escapeHtml(window.end || '07:00')}" />
            <label class="muted">Daily limit</label>
            <select class="f-limit">
              <option value="0" ${(window.dailyLimitMinutes || 0) === 0 ? 'selected' : ''}>Off</option>
              ${Array.from({ length: 32 }, (_, i) => (i + 1) * 15).map(m => `<option value="${m}" ${Number(window.dailyLimitMinutes || 0) === m ? 'selected' : ''}>${minsToHm(m)}</option>`).join('')}
            </select>
          </div>

          <div class="row" style="margin-top:10px; justify-content:space-between;">
            <div class="muted">
              Daily usage: ${daily && daily.limitMinutes != null ? `${minsToHm(daily.usedMinutes || 0)} / ${minsToHm(daily.limitMinutes)} (${minsToHm(daily.remainingMinutes || 0)} left)` : 'Off'}
            </div>
            <div class="row">
              <button class="eventsBtn ghost">Events</button>
              <button class="saveBtn primary">Save</button>
            </div>
          </div>

          <pre class="code pairOut hidden"></pre>
          <pre class="code eventsOut hidden"></pre>
        </article>
      `;
    }).join('');
  }

  function renderMain(info = '') {
    addDebug('renderMain.start', { devices: (state.devices || []).length, invites: (state.invites || []).length });

    app.innerHTML = `
      <div class="top">
        <div>
          <h1>SpotChecker Parent Dashboard (Web)</h1>
          <div class="muted">Signed in as ${escapeHtml(state.me?.displayName || state.me?.email || state.me?.id || '')}</div>
          <div class="muted">Household: ${escapeHtml(state.household?.name || '')} · Role: ${escapeHtml(state.household?.role || '')}</div>
        </div>
        <div class="row">
          <input id="apiBase" value="${escapeHtml(state.apiBase)}" style="min-width:280px" />
          <button id="saveApi" class="ghost">Save API</button>
          <button id="refresh" class="ghost">Refresh</button>
          <button id="signOut" class="danger">Sign out</button>
        </div>
      </div>

      ${info ? `<p class="ok">${escapeHtml(info)}</p>` : ''}

      <div class="grid">
        <section class="card half">
          <h2>Profile</h2>
          <div class="row">
            <input id="displayName" placeholder="Your display name" value="${escapeHtml(state.me?.displayName || '')}" style="flex:1" />
            <button id="saveDisplayName" class="primary">Save Name</button>
          </div>
        </section>

        <section class="card half">
          <h2>Invite Co-parent</h2>
          <p class="muted">Send by email, or share 4-character code. It can be entered at <code>web.spotchecker.app</code>.</p>
          <div class="row">
            <input id="inviteName" placeholder="name (optional)" style="flex:1" />
            <input id="inviteEmail" placeholder="email (optional)" style="flex:1" />
            <button id="createInvite" class="primary">Create Invite</button>
          </div>
          <div id="inviteList" class="col" style="margin-top:10px;">${buildInviteList()}</div>
        </section>

        <section class="card half">
          <h2>Household Members</h2>
          <div id="memberList" class="col">${buildMembersList()}</div>

          <hr class="sep" />

          <h3>Accept by Code</h3>
          <div class="row">
            <input id="inviteCode" placeholder="Enter invite code" />
            <button id="acceptCodeInvite">Accept Code</button>
          </div>
        </section>

        <section class="card">
          <div class="row" style="justify-content:space-between; margin-bottom:8px;">
            <h2>Children</h2>
            <div class="row">
              <input id="newChildName" placeholder="Child name" />
              <button id="createChild" class="primary">Add Child</button>
            </div>
          </div>
          <div id="deviceList" class="device-list">${buildDeviceCards()}</div>
        </section>
      </div>
    `;

    document.getElementById('saveApi').onclick = () => {
      state.apiBase = document.getElementById('apiBase').value.trim();
      localStorage.setItem(API_BASE_KEY, state.apiBase);
      loadAll();
    };

    document.getElementById('refresh').onclick = () => loadAll();
    document.getElementById('signOut').onclick = () => {
      state.sessionToken = '';
      localStorage.removeItem(SESSION_KEY);
      renderAuthOnly();
    };

    document.getElementById('saveDisplayName').onclick = async () => {
      const displayName = document.getElementById('displayName').value.trim();
      if (!displayName) return;
      try {
        await api('/api/me/profile', { method: 'PATCH', body: JSON.stringify({ displayName }) });
        await loadAll('Display name updated.');
      } catch (e) {
        alert(`Save name failed: ${e.message}`);
      }
    };

    document.getElementById('createInvite').onclick = async () => {
      const email = document.getElementById('inviteEmail').value.trim();
      const inviteName = document.getElementById('inviteName').value.trim();
      try {
        await api('/api/household/invites', {
          method: 'POST',
          body: JSON.stringify({ email: email || undefined, inviteName: inviteName || undefined })
        });
        await loadAll('Invite created.');
      } catch (e) {
        alert(`Invite failed: ${e.message}`);
      }
    };

    document.getElementById('acceptCodeInvite').onclick = async () => {
      const code = document.getElementById('inviteCode').value.trim().toUpperCase();
      if (!code) return;
      try {
        await api('/api/household/invite-code/accept', { method: 'POST', body: JSON.stringify({ code }) });
        await loadAll('Invite accepted.');
      } catch (e) {
        alert(`Code accept failed: ${e.message}`);
      }
    };

    document.getElementById('createChild').onclick = async () => {
      const name = document.getElementById('newChildName').value.trim();
      if (!name) return;
      try {
        await api('/api/devices', { method: 'POST', body: JSON.stringify({ name }) });
        await loadAll('Child added.');
      } catch (e) {
        alert(`Create child failed: ${e.message}`);
      }
    };

    const deviceCards = app.querySelectorAll('.device-card[data-device-id]');
    addDebug('renderMain.bind.deviceCards', { count: deviceCards.length });
    deviceCards.forEach(card => {
      try {
        const id = card.getAttribute('data-device-id');
        const daySel = card.querySelector('.f-day');
        addDebug('renderMain.bind.card', { id: id || '', hasDaySel: !!daySel });
        if (!id || !daySel) return;
        daySel.onchange = () => {
          state.selectedDayByDevice[id] = daySel.value;
          renderMain();
        };

        const pairOut = card.querySelector('.pairOut');
        const eventsOut = card.querySelector('.eventsOut');

        const pairBtn = card.querySelector('.pairBtn');
        if (pairBtn) pairBtn.onclick = async () => {
          try {
            const out = await api(`/api/devices/${id}/pairing-code`, { method: 'POST', body: JSON.stringify({ ttlMinutes: 10 }) });
            if (pairOut) {
              pairOut.classList.remove('hidden');
              pairOut.textContent = `${out.code} (expires ${new Date(out.expiresAt).toLocaleString()})`;
            }
          } catch (e) {
            alert(`Pairing code failed: ${e.message}`);
          }
        };

        const eventsBtn = card.querySelector('.eventsBtn');
        if (eventsBtn) eventsBtn.onclick = async () => {
          try {
            const out = await api(`/api/devices/${id}/events`);
            if (eventsOut) {
              eventsOut.classList.remove('hidden');
              eventsOut.textContent = JSON.stringify(out.events || [], null, 2);
            }
          } catch (e) {
            alert(`Events failed: ${e.message}`);
          }
        };

        const del = card.querySelector('.delBtn');
        if (del) {
          del.onclick = async () => {
            if (!confirm('Delete this child device?')) return;
            try {
              await api(`/api/devices/${id}`, { method: 'DELETE' });
              await loadAll('Child deleted.');
            } catch (e) {
              alert(`Delete failed: ${e.message}`);
            }
          };
        }

        const saveBtn = card.querySelector('.saveBtn');
        if (!saveBtn) return;
        saveBtn.onclick = async () => {
          const activateProtection = !!card.querySelector('.f-activateProtection').checked;
          const setHotspotOff = !!card.querySelector('.f-setHotspotOff').checked;
          const setWifiOff = !!card.querySelector('.f-setWifiOff').checked;
          const setMobileDataOff = !!card.querySelector('.f-setMobileDataOff').checked;
          const day = card.querySelector('.f-day').value;
          const start = card.querySelector('.f-start').value;
          const end = card.querySelector('.f-end').value;
          const dailyLimitMinutes = Number(card.querySelector('.f-limit').value || 0);

          const quietDays = {};
          const existing = (state.devices.find(x => x.id === id)?.quietDays) || {};
          for (const k of ['sun','mon','tue','wed','thu','fri','sat']) {
            const cur = existing[k] || { start: '22:00', end: '07:00', dailyLimitMinutes: 0 };
            quietDays[k] = { start: cur.start || '22:00', end: cur.end || '07:00', dailyLimitMinutes: Number(cur.dailyLimitMinutes || 0) };
          }
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
          } catch (e) {
            alert(`Save failed: ${e.message}`);
          }
        };
      } catch (e) {
        addDebug('renderMain.bind.card.failed', { message: e.message || String(e), stack: e.stack || '' });
      }
    });
  }

  async function loadAll(info = '') {
    try {
      addDebug('loadAll.start', { apiBase: state.apiBase, hasSession: !!state.sessionToken });
      const inviteCode = inviteAcceptCodeFromUrl();
      if (inviteCode && /^[A-Z0-9]{4}$/.test(inviteCode)) {
        addDebug('loadAll.preAuthInviteCode.attempt', { inviteCode });
        try {
          await api('/api/household/invite-code/accept', { method: 'POST', body: JSON.stringify({ code: inviteCode }) });
          clearInviteCodeFromUrl();
          info = info || 'Invite code accepted.';
          addDebug('loadAll.preAuthInviteCode.accepted', { inviteCode });
        } catch (e) {
          addDebug('loadAll.preAuthInviteCode.failed', { message: e.message || String(e) });
          renderAuthOnly(`Invite code failed: ${e.message}`);
          return;
        }
      }

      const [me, members, invites, dash] = await Promise.all([
        api('/api/me'),
        api('/api/household/members'),
        api('/api/household/invites'),
        api('/api/dashboard')
      ]);

      state.me = me.parent;
      state.household = me.household;
      state.members = members.members || [];
      state.invites = invites.invites || [];
      state.devices = dash.devices || [];
      addDebug('loadAll.data', { members: state.members.length, invites: state.invites.length, devices: state.devices.length });

      try {
        renderMain(info);
      } catch (e) {
        addDebug('loadAll.renderMain.failed', { message: e.message || String(e), stack: e.stack || '' });
        renderAuthOnly(`Load failed: ${e.message}`);
      }
    } catch (e) {
      addDebug('loadAll.failed', { message: e.message || String(e), stack: e.stack || '' });
      if (String(e.message || '').includes('unauthorized')) {
        state.sessionToken = '';
        localStorage.removeItem(SESSION_KEY);
        renderAuthOnly('Session expired. Sign in again.');
        return;
      }
      renderAuthOnly(`Load failed: ${e.message}`);
    }
  }

  async function boot() {
    parseHashSession();
    if (!state.sessionToken) {
      renderAuthOnly();
      return;
    }
    await loadAll();
  }

  boot();
})();
