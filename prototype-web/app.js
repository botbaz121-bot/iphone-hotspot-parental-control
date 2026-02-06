// Hotspot Parent — Clickable Mockup (static HTML/JS)
// No bundler, no framework. Keep it hackable.

const el = (tag, attrs = {}, children = []) => {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (k === 'class') node.className = v;
    else if (k === 'html') node.innerHTML = v;
    else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2).toLowerCase(), v);
    else if (v !== undefined) node.setAttribute(k, v);
  }
  for (const c of (Array.isArray(children) ? children : [children])) {
    if (c === null || c === undefined) continue;
    if (typeof c === 'string') node.appendChild(document.createTextNode(c));
    else node.appendChild(c);
  }
  return node;
};

const state = {
  mode: localStorage.getItem('hp.mode') || null, // parent|childsetup
  signedIn: localStorage.getItem('hp.signedIn') === '1',
  parentName: 'Leon',
  devices: [
    {
      id: 'dev_1',
      name: 'Child iPhone',
      status: 'OK', // OK|STALE|SETUP
      lastCheckInMinutes: 12,
      hotspotOff: true,
      quietTimeEnabled: true,
      quietStart: '22:00',
      quietEnd: '07:00',
      latest: { hotspotOff: 'success', rotatePassword: 'success' },
      activity: [
        { t: '15:05', msg: 'Activity OK' },
        { t: '15:20', msg: 'Policy fetch OK' },
        { t: '15:35', msg: 'Policy run logged' },
      ],
    },
    {
      id: 'dev_2',
      name: 'iPhone (Spare)',
      status: 'STALE',
      lastCheckInMinutes: 180,
      hotspotOff: true,
      quietTimeEnabled: false,
      quietStart: '22:00',
      quietEnd: '07:00',
      latest: { hotspotOff: 'failed', rotatePassword: 'success' },
      activity: [
        { t: '12:00', msg: 'Activity OK' },
        { t: '13:00', msg: '⚠️ Stale activity' },
      ],
    },
  ],
  selectedDeviceId: localStorage.getItem('hp.selectedDeviceId') || 'dev_1',
  childSetup: {
    paired: false,
    shortcutInstalled: false,
    appIntentAdded: false,
    automationsEnabled: false,
    screenTimeAuthorized: false,
    screenTimePasscodeSet: false,
    shieldingApplied: false,
  },
};

const persist = () => {
  localStorage.setItem('hp.mode', state.mode || '');
  localStorage.setItem('hp.signedIn', state.signedIn ? '1' : '0');
  localStorage.setItem('hp.selectedDeviceId', state.selectedDeviceId);
};

const route = {
  get path() {
    const h = location.hash || '#/';
    return h.replace(/^#/, '');
  },
  go(p) {
    location.hash = p.startsWith('/') ? `#${p}` : `#/${p}`;
  },
};

const appRoot = document.getElementById('app');

// Add a class so Framework7 styles apply
appRoot.classList.add('f7');

function navbar({ title, backTo, rightText }) {
  return el('div', { class: 'navbar' },
    el('div', { class: 'navbar-inner' }, [
      backTo
        ? el('button', { class: 'iconbtn', onClick: () => route.go(backTo), 'aria-label': 'Back' }, '‹')
        : el('div', { style: 'width:36px' }),
      el('div', { class: 'nav-title' }, title),
      el('div', { class: 'nav-sub' }, rightText || ''),
    ])
  );
}

function tabs(active) {
  if (state.mode !== 'parent' || !state.signedIn) return null;
  const items = [
    { key: 'dashboard', label: 'Dashboard', to: '/parent/dashboard' },
    { key: 'devices', label: 'Devices', to: '/parent/devices' },
    { key: 'settings', label: 'Settings', to: '/parent/settings' },
  ];
  return el('div', { class: 'tabs' }, items.map(it =>
    el('a', { class: `tab ${active === it.key ? 'active' : ''}`, href: `#${it.to}` }, [
      el('div', { class: 'small' }, it.label),
    ])
  ));
}

function badgeFor(status) {
  if (status === 'OK') return el('span', { class: 'badge good' }, 'OK');
  if (status === 'STALE') return el('span', { class: 'badge warn' }, 'STALE');
  if (status === 'SETUP') return el('span', { class: 'badge muted' }, 'SETUP');
  return el('span', { class: 'badge muted' }, status);
}

function getDevice() {
  return state.devices.find(d => d.id === state.selectedDeviceId) || state.devices[0];
}

function toggleSwitch(on, onToggle) {
  return el('div', { class: `switch ${on ? 'on' : ''}`, onClick: onToggle, role: 'switch', 'aria-checked': on ? 'true' : 'false' });
}

// Screens
function screenLanding() {
  return {
    nav: navbar({ title: 'Hotspot Parent' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h1' }, 'Hotspot Parent'),
        el('p', { class: 'p' }, 'Clickable mockup to plan flows without iOS builds.'),
        el('hr', { class: 'sep' }),
        el('div', { class: 'h2' }, 'Choose mode'),
        el('div', { class: 'hstack' }, [
          el('button', { class: 'btn primary', onClick: () => { state.mode = 'parent'; persist(); route.go('/parent/onboarding'); } }, 'Parent phone'),
          el('button', { class: 'btn', onClick: () => { state.mode = 'childsetup'; persist(); route.go('/child/onboarding'); } }, 'Set up child phone'),
        ]),
      ]),
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Notes'),
        el('p', { class: 'p' }, 'Shortcuts-only enforcement. Child phone still installs the app so it can pair and provide config to the Shortcut via App Intent.'),
      ]),
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Reset mockup'),
        el('button', { class: 'btn danger', onClick: () => { localStorage.clear(); location.hash = '#/'; location.reload(); } }, 'Clear local state'),
      ]),
    ]),
  };
}

function screenParentOnboarding() {
  return {
    nav: navbar({ title: 'Welcome', backTo: '/' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h1' }, 'Welcome'),
        el('p', { class: 'p' }, 'This app helps parents deter hotspot use via Shortcuts and track device activitys.'),
        el('div', { class: 'card', style: 'box-shadow:none; background: rgba(255,255,255,.04)' }, [
          el('div', { class: 'h2' }, 'What this can do'),
          el('p', { class: 'p' }, '• Set per-device policy (Hotspot OFF + Quiet Time)\n• Guide child phone setup\n• Show last activity + activity')
        ]),
        el('div', { class: 'card', style: 'box-shadow:none; background: rgba(255,255,255,.04)' }, [
          el('div', { class: 'h2' }, 'Constraint'),
          el('p', { class: 'p' }, 'iOS apps can’t reliably toggle Personal Hotspot directly; enforcement is performed by the Shortcut.')
        ]),
        el('button', { class: 'btn primary', onClick: () => route.go('/parent/signin') }, 'Continue'),
      ]),
    ]),
  };
}

function screenParentSignIn() {
  return {
    nav: navbar({ title: 'Sign In', backTo: '/parent/onboarding' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h1' }, 'Sign In'),
        el('p', { class: 'p' }, 'Mock sign-in (Sign in with Apple in real app).'),
        el('button', { class: 'btn primary', onClick: () => { state.signedIn = true; persist(); route.go('/parent/dashboard'); } }, 'Sign in'),
      ]),
    ]),
  };
}

function screenParentDashboard() {
  const device = getDevice();
  const stale = device.lastCheckInMinutes >= 120;
  return {
    nav: navbar({ title: 'Dashboard', rightText: `Signed in as ${state.parentName}` }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Device'),
        el('div', { class: 'segmented segmented-raised' }, state.devices.map(d =>
          el('a', {
            class: `button ${d.id === state.selectedDeviceId ? 'button-active' : ''}`,
            href: '#',
            onClick: (e) => { e.preventDefault(); state.selectedDeviceId = d.id; persist(); render(); }
          }, d.name)
        )),
        el('div', { class: 'hstack', style: 'justify-content:space-between; margin-top:10px' }, [
          el('div', { class: 'small' }, `Last seen: ${device.lastCheckInMinutes}m ago`),
          badgeFor(device.status),
        ]),
        el('div', { class: 'hstack', style: 'margin-top:10px' }, [
          el('button', { class: 'btn primary', onClick: () => route.go(`/parent/device/${device.id}`) }, 'Device details'),
          el('button', { class: 'btn', onClick: () => route.go('/parent/add-device') }, 'Add device'),
        ]),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Policy status'),
        el('div', { class: 'kv' }, [ el('div', { class: 'k' }, 'Hotspot OFF'), el('div', { class: 'v' }, device.hotspotOff ? 'ON' : 'OFF') ]),
        el('div', { class: 'kv' }, [ el('div', { class: 'k' }, 'Quiet Time'), el('div', { class: 'v' }, device.quietTimeEnabled ? `${device.quietStart}–${device.quietEnd}` : 'OFF') ]),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Tamper warning'),
        el('p', { class: 'p' }, stale
          ? '⚠️ Device may have been tampered with (no recent activity).'
          : 'No tamper warning (recent activity).'
        ),
        el('p', { class: 'p' }, 'If this persists: check automations, Shortcut still installed, network access, and Screen Time lock.'),
      ]),

      el('div', { class: 'card hstack' }, [
        el('button', { class: 'btn', onClick: () => route.go('/child/onboarding') }, 'Set up child phone'),
        el('button', { class: 'btn', onClick: () => route.go('/parent/settings') }, 'Settings'),
      ]),
    ]),
    tabs: tabs('dashboard'),
  };
}

function screenParentDevices() {
  return {
    nav: navbar({ title: 'Devices' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Devices'),
        el('div', { class: 'list' }, state.devices.map(d =>
          el('div', { class: 'row', onClick: () => route.go(`/parent/device/${d.id}`) }, [
            el('div', {}, [
              el('div', { class: 'title' }, d.name),
              el('div', { class: 'sub' }, `Last seen ${d.lastCheckInMinutes}m ago`),
            ]),
            badgeFor(d.status),
          ])
        )),
        el('button', { class: 'btn primary', onClick: () => route.go('/parent/add-device') }, '+ Add device'),
      ]),
    ]),
    tabs: tabs('devices'),
  };
}

function screenParentAddDevice() {
  const token = 'ABCD1234-EFGH-IJKL';
  return {
    nav: navbar({ title: 'Enroll Device', backTo: '/parent/devices' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Enrollment token'),
        el('div', { class: 'kv' }, [ el('div', { class: 'k' }, 'Token'), el('div', { class: 'v' }, token) ]),
        el('div', { class: 'hstack' }, [
          el('button', { class: 'btn', onClick: async () => { await navigator.clipboard.writeText(token); alert('Copied'); } }, 'Copy'),
          el('button', { class: 'btn', onClick: () => alert('Regenerate (mock)') }, 'Regenerate'),
        ]),
      ]),
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Next on the child phone'),
        el('p', { class: 'p' }, '1) Install the app on the child phone\n2) Open app → Set up child phone → Pair device → Scan QR\n3) Install the Shortcut\n4) Ensure Shortcut starts with “Get Hotspot Config”\n5) Create automations\n6) Apply Screen Time lock'),
        el('div', { class: 'hstack' }, [
          el('button', { class: 'btn primary', onClick: () => route.go('/child/onboarding') }, 'Go to child setup'),
          el('button', { class: 'btn', onClick: () => alert('Open Shortcut link (mock)') }, 'Open Shortcut link'),
        ]),
      ]),
    ]),
  };
}

function screenParentDeviceDetails(deviceId) {
  const d = state.devices.find(x => x.id === deviceId) || getDevice();
  const stale = d.lastCheckInMinutes >= 120;
  return {
    nav: navbar({ title: d.name, backTo: '/parent/devices' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'hstack' }, [
          el('div', { class: 'h2' }, 'Overview'),
          badgeFor(d.status),
        ]),
        el('p', { class: 'p' }, `Last seen: ${d.lastCheckInMinutes}m ago`),
        stale ? el('div', { class: 'badge warn' }, '⚠️ Stale activity') : el('div', { class: 'badge good' }, 'Recent activity'),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Policy'),
        el('div', { class: 'toggle' }, [
          el('div', {}, [el('div', { style:'font-weight:700' }, 'Hotspot OFF'), el('div', { class:'small' }, 'Shortcut turns off hotspot + rotates password')]),
          toggleSwitch(d.hotspotOff, () => { d.hotspotOff = !d.hotspotOff; render(); }),
        ]),
        el('div', { class: 'toggle' }, [
          el('div', {}, [el('div', { style:'font-weight:700' }, 'In Quiet Time'), el('div', { class:'small' }, 'Per-device schedule')]),
          toggleSwitch(d.quietTimeEnabled, () => { d.quietTimeEnabled = !d.quietTimeEnabled; render(); }),
        ]),
        d.quietTimeEnabled ? el('div', { class: 'hstack' }, [
          el('div', { style:'flex:1' }, [el('div', { class:'small' }, 'Start'), el('input', { class:'field', value: d.quietStart, onInput: (e)=>{d.quietStart=e.target.value;} })]),
          el('div', { style:'flex:1' }, [el('div', { class:'small' }, 'End'), el('input', { class:'field', value: d.quietEnd, onInput: (e)=>{d.quietEnd=e.target.value;} })]),
        ]) : null,
        el('button', { class:'btn primary', onClick: () => alert('Saved (mock)') }, 'Save'),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Activity'),
        el('div', { class: 'list' }, d.activity.map(a =>
          el('div', { class:'row' }, [
            el('div', {}, [el('div', { class:'title' }, a.msg), el('div', { class:'sub' }, a.t)]),
            el('span', { class:'badge muted' }, 'View')
          ])
        )),
      ]),

      el('div', { class:'card vstack' }, [
        el('div', { class:'h2' }, 'Troubleshooting'),
        el('button', { class:'btn', onClick: () => alert('Show troubleshooting (mock)') }, 'Child Shortcut not running'),
        el('button', { class:'btn danger', onClick: () => alert('Remove device (mock)') }, 'Remove device'),
      ]),
    ]),
  };
}

function screenParentSettings() {
  return {
    nav: navbar({ title: 'Settings' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Account'),
        el('div', { class: 'kv' }, [ el('div', { class: 'k' }, 'Signed in'), el('div', { class: 'v' }, state.signedIn ? 'Yes' : 'No') ]),
        el('button', { class: 'btn danger', onClick: () => { state.signedIn = false; persist(); route.go('/'); } }, 'Sign out'),
      ]),
      el('div', { class:'card vstack' }, [
        el('div', { class:'h2' }, 'Debug'),
        el('p', { class:'p' }, 'Mockup only.'),
      ]),
    ]),
    tabs: tabs('settings'),
  };
}

function screenChildOnboarding() {
  return {
    nav: navbar({ title: 'Set up child phone', backTo: '/' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h1' }, 'Child phone setup'),
        el('p', { class: 'p' }, 'Parent uses the child phone to pair, then sets up the Shortcut + Screen Time lock.'),
        el('button', { class: 'btn primary', onClick: () => route.go('/child/pair') }, 'Start pairing'),
        el('button', { class: 'btn', onClick: () => route.go('/child/checklist') }, 'Open checklist'),
      ]),
    ]),
  };
}

function screenChildPair() {
  const c = state.childSetup;
  const paired = c.paired;
  return {
    nav: navbar({ title: 'Pair device', backTo: '/child/checklist' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Scan QR'),
        el('p', { class: 'p' }, 'On the real app, this uses the camera. In this mockup, it just simulates success.'),
        el('button', { class: 'btn primary', onClick: () => { c.paired = true; alert('Paired (mock)'); route.go('/child/checklist'); } }, paired ? 'Re-scan (mock)' : 'Scan QR (mock)'),
      ]),
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Or enter pairing code'),
        el('input', { class: 'field', placeholder: 'e.g. ABCD-1234', value: c._pairCode || '', onInput: (e) => { c._pairCode = e.target.value; } }),
        el('button', { class: 'btn', onClick: () => { if ((c._pairCode||'').trim().length < 4) return alert('Enter a code'); c.paired = true; alert('Paired (mock)'); route.go('/child/checklist'); } }, 'Pair'),
        el('p', { class: 'p' }, 'Pairing stores device credentials securely in the app (used by the Shortcut via App Intent).'),
      ]),
    ]),
  };
}

function screenChildScreenTime() {
  const c = state.childSetup;
  return {
    nav: navbar({ title: 'Screen Time lock', backTo: '/child/checklist' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Shield apps'),
        el('p', { class: 'p' }, 'In the real app, we show Apple’s picker (FamilyControls) then apply shielding (ManagedSettings).'),
        el('div', { class: 'list' }, [
          el('div', { class:'row', onClick: () => { c._shieldSettings = !c._shieldSettings; render(); } }, [
            el('div', {}, [el('div', { class:'title' }, 'Settings'), el('div', { class:'sub' }, 'Recommended')]),
            el('span', { class: `badge ${c._shieldSettings?'good':'muted'}` }, c._shieldSettings?'Selected':'Not')
          ]),
          el('div', { class:'row', onClick: () => { c._shieldShortcuts = !c._shieldShortcuts; render(); } }, [
            el('div', {}, [el('div', { class:'title' }, 'Shortcuts'), el('div', { class:'sub' }, 'Recommended')]),
            el('span', { class: `badge ${c._shieldShortcuts?'good':'muted'}` }, c._shieldShortcuts?'Selected':'Not')
          ]),
        ]),
        el('button', { class: 'btn primary', onClick: () => { c.shieldingApplied = true; alert('Shielding applied (mock)'); route.go('/child/checklist'); } }, 'Apply shielding'),
        el('p', { class: 'p' }, 'Reminder: you must set a Screen Time passcode in Settings (we can’t set it for you).'),
      ]),
    ]),
  };
}

function stepRow(done, title, sub, onToggle) {
  return el('div', { class:'row' }, [
    el('div', {}, [
      el('div', { class:'title' }, title),
      el('div', { class:'sub' }, sub),
    ]),
    el('button', { class: `btn ${done?'primary':''}`, onClick: onToggle }, done ? 'Done' : 'Mark done')
  ]);
}

function screenChildChecklist() {
  const c = state.childSetup;
  return {
    nav: navbar({ title: 'Child phone setup', backTo: '/child/onboarding' }),
    body: el('div', { class: 'content' }, [
      el('div', { class:'card vstack' }, [
        el('div', { class:'h2' }, '1) Pair device'),
        el('p', { class:'p' }, c.paired ? 'Paired ✅' : 'Not paired yet.'),
        el('div', { class:'hstack' }, [
          el('button', { class:'btn primary', onClick: () => route.go('/child/pair') }, c.paired ? 'View pairing' : 'Start pairing'),
          c.paired ? el('button', { class:'btn', onClick: () => { c.paired = false; render(); } }, 'Unpair') : null,
        ].filter(Boolean)),
      ]),

      el('div', { class:'card vstack' }, [
        el('div', { class:'h2' }, '2) Shortcut'),
        stepRow(c.shortcutInstalled, 'Install Shortcut', 'Open shortcut link and add it', () => { c.shortcutInstalled = !c.shortcutInstalled; render(); }),
        stepRow(c.appIntentAdded, 'Add “Get Hotspot Config”', 'Ensure the first step is the App Intent', () => { c.appIntentAdded = !c.appIntentAdded; render(); }),
        el('div', { class:'hstack' }, [
          el('button', { class:'btn', onClick: () => alert('Open Shortcut link (mock)') }, 'Open Shortcut link'),
        ]),
      ]),

      el('div', { class:'card vstack' }, [
        el('div', { class:'h2' }, '3) Automations'),
        stepRow(c.automationsEnabled, 'Enable automations', 'Battery + time-of-day', () => { c.automationsEnabled = !c.automationsEnabled; render(); }),
      ]),

      el('div', { class:'card vstack' }, [
        el('div', { class:'h2' }, '4) Screen Time lock'),
        el('p', { class:'p' }, 'We do the shielding in-app, but you must set a Screen Time passcode manually.'),
        el('div', { class:'list' }, [
          el('div', { class:'row', onClick: () => { c.screenTimeAuthorized = true; render(); } }, [
            el('div', {}, [el('div', { class:'title' }, 'Authorize Screen Time'), el('div', { class:'sub' }, 'Grant permission in-app (FamilyControls)')]),
            el('span', { class: `badge ${c.screenTimeAuthorized?'good':'muted'}` }, c.screenTimeAuthorized?'Done':'Todo'),
          ]),
          el('div', { class:'row', onClick: () => { c.screenTimePasscodeSet = true; render(); } }, [
            el('div', {}, [el('div', { class:'title' }, 'Set Screen Time passcode'), el('div', { class:'sub' }, 'Parent sets passcode in Settings')]),
            el('span', { class: `badge ${c.screenTimePasscodeSet?'good':'muted'}` }, c.screenTimePasscodeSet?'Done':'Todo'),
          ]),
          el('div', { class:'row', onClick: () => route.go('/child/screentime') }, [
            el('div', {}, [el('div', { class:'title' }, 'Select apps to shield'), el('div', { class:'sub' }, 'Recommended: Settings + Shortcuts')]),
            el('span', { class: 'badge muted' }, 'Open'),
          ]),
        ]),
      ]),

      el('div', { class:'card hstack' }, [
        el('button', { class:'btn', onClick: () => { alert('Done. Hand phone back to child.'); } }, 'Done'),
        el('button', { class:'btn primary', onClick: () => route.go('/parent/dashboard') }, 'Back to parent dashboard'),
      ]),
    ]),
  };
}

function resolveScreen() {
  const p = route.path;
  if (p === '/' || p === '') return screenLanding();

  // Parent flow
  if (p === '/parent/onboarding') return screenParentOnboarding();
  if (p === '/parent/signin') return screenParentSignIn();
  if (p === '/parent/dashboard') return screenParentDashboard();
  if (p === '/parent/devices') return screenParentDevices();
  if (p === '/parent/add-device') return screenParentAddDevice();
  if (p.startsWith('/parent/device/')) return screenParentDeviceDetails(p.split('/').pop());
  if (p === '/parent/settings') return screenParentSettings();

  // Child setup flow
  if (p === '/child/onboarding') return screenChildOnboarding();
  if (p === '/child/checklist') return screenChildChecklist();
  if (p === '/child/pair') return screenChildPair();
  if (p === '/child/screentime') return screenChildScreenTime();

  return {
    nav: navbar({ title: 'Not Found', backTo: '/' }),
    body: el('div', { class: 'content' }, el('div', { class: 'card' }, 'Unknown route')),
  };
}

function render() {
  const s = resolveScreen();
  appRoot.innerHTML = '';
  appRoot.appendChild(s.nav);
  appRoot.appendChild(s.body);
  if (s.tabs) appRoot.appendChild(s.tabs);
}

window.addEventListener('hashchange', render);

// Initial route
if (!location.hash) location.hash = '#/';
render();
