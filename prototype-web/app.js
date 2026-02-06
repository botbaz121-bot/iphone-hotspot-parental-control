// HomeGriffin — Clickable Mockup (static HTML/JS)
// No bundler. Keep it hackable.

import { ICON_SVGS } from './iconset.js';

const el = (tag, attrs = {}, children = []) => {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (k === 'class') node.className = v;
    else if (k === 'style') node.setAttribute('style', v);
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
  isChildPhone: localStorage.getItem('hp.isChildPhone') === '1',
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
  localStorage.setItem('hp.isChildPhone', state.isChildPhone ? '1' : '0');
  localStorage.setItem('hp.selectedDeviceId', state.selectedDeviceId);
};

/* ---------- Navigation history (for reliable Back) ---------- */

const navState = {
  stacks: (() => {
    try {
      return JSON.parse(localStorage.getItem('hp.navStacks') || '{"parent":[],"child":[]}') || { parent: [], child: [] };
    } catch {
      return { parent: [], child: [] };
    }
  })(),
  lastParentRoute: localStorage.getItem('hp.lastParentRoute') || '/parent/dashboard',
  // When switching tabs, iOS doesn’t treat it as “back stack”; we replace the top.
  _isTabSwitch: false,
};

function navKeyForPath(p) {
  if ((p || '').startsWith('/child/')) return 'child';
  return 'parent';
}

function navPersist() {
  try { localStorage.setItem('hp.navStacks', JSON.stringify({
    parent: (navState.stacks.parent || []).slice(-60),
    child: (navState.stacks.child || []).slice(-60),
  })); } catch {}
  try { localStorage.setItem('hp.lastParentRoute', navState.lastParentRoute || '/parent/dashboard'); } catch {}
}

function navReset() {
  navState.stacks.parent = [];
  navState.stacks.child = [];
  navPersist();
}

function navTrack(path) {
  if (!path) return;
  const k = navKeyForPath(path);
  const stack = navState.stacks[k] || (navState.stacks[k] = []);

  if (k === 'parent') navState.lastParentRoute = path;

  const last = stack[stack.length - 1];
  if (last === path) {
    navState._isTabSwitch = false;
    navPersist();
    return;
  }

  if (navState._isTabSwitch && stack.length) {
    stack[stack.length - 1] = path;
  } else {
    stack.push(path);
  }

  navState._isTabSwitch = false;
  navPersist();
}

function navBack(fallback = '/') {
  const p = route.path || '/';
  const k = navKeyForPath(p);
  const stack = navState.stacks[k] || (navState.stacks[k] = []);

  if (stack.length > 1) stack.pop();
  const prev = stack[stack.length - 1];
  navPersist();
  route.go(prev || fallback);
}

function navTabGo(to) {
  navState._isTabSwitch = true;
  route.go(to);
}

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
appRoot.classList.add('f7');

/* ---------- UI helpers ---------- */

function iconSquare(name = 'phone', extraClass = '') {
  const svg = ICON_SVGS[name] || ICON_SVGS.phone;
  return el('span', { class: `ic ic--${name} ${extraClass}`.trim(), 'aria-hidden': 'true', html: svg });
}

function navbar({ title, backTo, rightText, rightButton }) {
  return el('div', { class: 'navbar' },
    el('div', { class: 'navbar-inner' }, [
      backTo
        ? el('button', { class: 'iconbtn', onClick: () => navBack(backTo), 'aria-label': 'Back' }, '‹')
        : el('div', { style: 'width:38px' }),
      el('div', { class: 'nav-title' }, title),
      rightText ? el('div', { class: 'nav-sub' }, rightText) : el('div', { class: 'nav-sub' }, ''),
      rightButton || null,
    ].filter(Boolean))
  );
}

function parentTabs(active) {
  const items = [
    { key: 'dashboard', label: 'Dashboard', to: '/parent/dashboard' },
    { key: 'settings', label: 'Settings', to: '/parent/settings' },
  ];
  return el('div', { class: 'tabs', role: 'tablist', 'aria-label': 'Parent tabs' }, items.map(it =>
    el('button', {
      class: `btab ${active === it.key ? 'active' : ''}`,
      onClick: () => navTabGo(it.to),
      role: 'tab',
      'aria-selected': active === it.key ? 'true' : 'false'
    }, it.label)
  ));
}

function childTabs(active) {
  const items = [
    { key: 'dashboard', label: 'Dashboard', to: '/child/dashboard' },
    { key: 'settings', label: 'Settings', to: '/child/settings' },
  ];
  return el('div', { class: 'tabs', role: 'tablist', 'aria-label': 'Child tabs' }, items.map(it =>
    el('button', {
      class: `btab ${active === it.key ? 'active' : ''}`,
      onClick: () => navTabGo(it.to),
      role: 'tab',
      'aria-selected': active === it.key ? 'true' : 'false'
    }, it.label)
  ));
}

function bottomTabs(active) {
  const p = route.path || '/';
  if (p.startsWith('/parent/')) return parentTabs(active);
  if (p.startsWith('/child/')) return childTabs(active);
  return null;
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
  return el('div', {
    class: `switch ${on ? 'on' : ''}`,
    onClick: onToggle,
    role: 'switch',
    'aria-checked': on ? 'true' : 'false'
  });
}

/* ---------- Bottom sheet modal ---------- */

let activeSheet = null;

function closeSheet() {
  if (!activeSheet) return;
  const { scrim, sheet, onClose } = activeSheet;
  scrim.classList.remove('open');
  sheet.classList.remove('open');
  document.documentElement.style.overflow = '';

  // Let the animation finish.
  window.setTimeout(() => {
    scrim.remove();
    sheet.remove();
    if (typeof onClose === 'function') onClose();
  }, 180);
  activeSheet = null;
}

function openSheet({ title, body, actions = [], onClose }) {
  closeSheet();

  const scrim = el('div', { class: 'sheet-scrim', onClick: closeSheet, role: 'button', 'aria-label': 'Close dialog' });
  const sheet = el('div', { class: 'sheet', role: 'dialog', 'aria-modal': 'true' }, [
    el('div', { class: 'sheet-handle', 'aria-hidden': 'true' }),
    el('div', { class: 'sheet-header' }, [
      el('div', { class: 'sheet-title' }, title || ''),
      el('button', { class: 'iconbtn', onClick: closeSheet, 'aria-label': 'Close' }, '×')
    ]),
    el('div', { class: 'sheet-body' }, [
      body,
      actions?.length
        ? el('div', { class: 'sheet-actions' }, actions)
        : null
    ].filter(Boolean)),
  ]);

  document.body.appendChild(scrim);
  document.body.appendChild(sheet);
  document.documentElement.style.overflow = 'hidden';

  // Next frame: animate open.
  requestAnimationFrame(() => {
    scrim.classList.add('open');
    sheet.classList.add('open');
  });

  const onKey = (e) => {
    if (e.key === 'Escape') closeSheet();
  };
  window.addEventListener('keydown', onKey, { once: true });

  activeSheet = { scrim, sheet, onClose };
}

function enrollmentSheet({ backTo }) {
  const token = 'ABCD1234-EFGH-IJKL';
  const tmp = { name: '' };

  openSheet({
    title: 'Add device',
    body: el('div', { class: 'vstack' }, [
      el('div', { class: 'card soft vstack', style: 'padding:12px' }, [
        el('div', { class: 'h2' }, 'Device name'),
        el('input', {
          class: 'field',
          placeholder: 'e.g. Jack\'s iPhone',
          value: tmp.name,
          onInput: (e) => { tmp.name = e.target.value; },
        }),
        el('p', { class: 'small' }, 'Shown in the device switcher.'),
      ]),

      el('div', { class: 'card soft vstack', style: 'padding:12px' }, [
        el('div', { class: 'h2' }, 'Enrollment QR'),
        el('div', { class: 'kv' }, [
          el('div', { class: 'k' }, 'Token'),
          el('div', { class: 'v' }, token)
        ]),
        el('div', { class: 'hstack' }, [
          el('button', {
            class: 'btn',
            onClick: async () => {
              try {
                await navigator.clipboard.writeText(token);
                alert('Copied');
              } catch {
                alert('Copy failed (browser permissions)');
              }
            }
          }, [iconSquare('copy'), 'Copy token']),
          el('button', { class: 'btn ghost', onClick: () => alert('Regenerate (mock)') }, [iconSquare('refresh'), 'Regenerate']),
        ]),
        el('p', { class: 'small' }, 'The parent scans this on the child phone during pairing.'),
      ]),

      el('div', { class: 'card soft vstack', style: 'padding:12px' }, [
        el('div', { class: 'h2' }, 'Next on the child phone'),
        el('div', { class: 'vstack' }, [
          el('div', { class: 'row' }, [
            el('div', { class: 'hstack' }, [
              iconSquare('app'),
              el('div', {}, [
                el('div', { class: 'title' }, 'Open this app'),
                el('div', { class: 'sub' }, 'Set up child phone → Pair device')
              ])
            ]),
            el('span', { class: 'badge muted' }, '1')
          ]),
          el('div', { class: 'row' }, [
            el('div', { class: 'hstack' }, [
              iconSquare('link'),
              el('div', {}, [
                el('div', { class: 'title' }, 'Install the Shortcut'),
                el('div', { class: 'sub' }, 'Add “Get Hotspot Config” at the start')
              ])
            ]),
            el('span', { class: 'badge muted' }, '2')
          ]),
          el('div', { class: 'row' }, [
            el('div', { class: 'hstack' }, [
              iconSquare('clock'),
              el('div', {}, [
                el('div', { class: 'title' }, 'Create automations'),
                el('div', { class: 'sub' }, 'Battery + time-of-day')
              ])
            ]),
            el('span', { class: 'badge muted' }, '3')
          ]),
          el('div', { class: 'row' }, [
            el('div', { class: 'hstack' }, [
              iconSquare('shield'),
              el('div', {}, [
                el('div', { class: 'title' }, 'Apply Screen Time lock'),
                el('div', { class: 'sub' }, 'Authorize + set passcode + shield apps')
              ])
            ]),
            el('span', { class: 'badge muted' }, '4')
          ]),
        ])
      ]),
    ]),
    actions: [
      el('button', {
        class: 'btn primary full',
        onClick: () => {
          const name = (tmp.name || '').trim() || 'Child iPhone';
          const id = `dev_${Math.random().toString(16).slice(2,8)}`;
          state.devices.unshift({
            id,
            name,
            status: 'SETUP',
            lastCheckInMinutes: 0,
            hotspotOff: true,
            quietTimeEnabled: false,
            quietStart: '22:00',
            quietEnd: '07:00',
            latest: { hotspotOff: 'unknown', rotatePassword: 'unknown' },
            activity: [{ t: 'Now', msg: 'Device added (setup pending)' }],
          });
          state.selectedDeviceId = id;
          persist();
          closeSheet();
          route.go('/parent/dashboard');
        }
      }, [iconSquare('qr'), 'Add device']),

      el('button', { class: 'btn full', onClick: () => { closeSheet(); route.go('/child/onboarding'); } }, 'Set up child phone'),
      backTo ? el('button', { class: 'btn full', onClick: () => { closeSheet(); route.go(backTo); } }, 'Close') : null,
    ].filter(Boolean),
  });
}

/* ---------- Screens ---------- */

function screenLanding() {
  return {
    nav: navbar({ title: 'HomeGriffin' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'hero' }, [
        el('div', { class: 'hero-top' }, [
          el('div', {}, [
            el('h1', { class: 'hero-title' }, 'HomeGriffin'),
            el('p', { class: 'hero-sub' }, 'High‑fidelity prototype to design parent + child setup flows (no iOS build).'),
          ]),
          el('span', { class: 'badge muted' }, 'Prototype'),
        ]),
        el('div', { class: 'hero-actions' }, [
          el('button', { class: 'btn primary', onClick: () => { navReset(); state.mode = 'parent'; persist(); route.go('/parent/onboarding'); } }, [iconSquare('parent'), 'Parent phone']),
          el('button', { class: 'btn', onClick: () => { navReset(); state.mode = 'childsetup'; persist(); route.go('/child/onboarding'); } }, [iconSquare('child'), 'Set up child phone']),
        ]),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'What this models'),
        el('p', { class: 'p' }, 'Shortcuts-only enforcement (hotspot off + password rotation), device activity signals, and a guided child-phone checklist.'),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Reset mockup'),
        el('button', {
          class: 'btn danger',
          onClick: () => {
            localStorage.clear();
            location.hash = '#/';
            location.reload();
          }
        }, [iconSquare('trash'), 'Clear local state']),
        el('p', { class: 'small' }, 'Clears localStorage only (no server).'),
      ]),
    ]),
  };
}

function featureTile({ icon, title, sub }) {
  return el('div', { class: 'feature-tile' }, [
    el('div', { class: 'feature-top' }, [
      el('div', { class: 'feature-icon' }, iconSquare(icon)),
      el('div', { class: 'feature-title' }, title),
    ]),
    el('div', { class: 'feature-sub' }, sub),
  ]);
}

function screenParentOnboarding() {
  return {
    nav: navbar({ title: 'Welcome', backTo: '/' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'hero' }, [
        el('div', { class: 'hero-top' }, [
          el('div', {}, [
            el('h1', { class: 'hero-title' }, 'Welcome'),
            el('p', { class: 'hero-sub' }, 'Set rules, guide setup on the child phone, and get a simple tamper warning if it stops running.'),
          ]),
          el('span', { class: 'badge muted' }, 'Parent'),
        ]),
        el('div', { class: 'hero-actions' }, [
          el('button', { class: 'btn primary', onClick: () => route.go('/parent/signin') }, [iconSquare('next'), 'Continue']),
          el('button', { class: 'btn ghost', onClick: () => route.go('/child/onboarding') }, [iconSquare('child'), 'Set up child phone']),
        ]),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'What this can do'),
        el('div', { class: 'feature-row' }, [
          featureTile({ icon: 'rules', title: 'Per-device rules', sub: 'Hotspot OFF and Quiet Time per child device.' }),
          featureTile({ icon: 'checklist', title: 'Guided setup', sub: 'Pair the child phone, install the Shortcut, and apply Screen Time shielding.' }),
          featureTile({ icon: 'alert', title: 'Tamper warning', sub: 'Warn when the phone hasn’t been seen recently (likely disabled).'}),
        ]),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Constraints'),
        el('p', { class: 'p' }, 'iOS apps can’t reliably toggle Personal Hotspot directly; enforcement is performed by the Shortcut on the device.'),
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
        el('p', { class: 'p' }, 'Mock sign‑in (Sign in with Apple in the real app).'),
        el('button', {
          class: 'btn primary full',
          onClick: () => {
            state.signedIn = true;
            persist();
            route.go('/parent/dashboard');
          }
        }, [iconSquare('login'), 'Sign in']),
      ]),
    ]),
  };
}

function deviceCarousel() {
  const cards = [];

  for (const d of state.devices) {
    cards.push(el('div', {
      class: `device-card ${d.id === state.selectedDeviceId ? 'selected' : ''}`,
      role: 'button',
      'aria-label': `Select ${d.name}`,
      onClick: () => {
        state.selectedDeviceId = d.id;
        persist();
        render();
      }
    }, [
      el('div', { class: 'dc-head' }, [
        el('div', { class: 'dc-avatar' }, [
          el('div', { class: 'dc-avatar-inner' }, d.name.slice(0,1).toUpperCase())
        ]),
        el('div', { class: 'dc-text' }, [
          el('div', { class: 'dc-name' }, d.name),
          el('div', { class: 'dc-sub' }, `Last seen ${d.lastCheckInMinutes}m ago`),
        ]),
        badgeFor(d.status)
      ]),
      el('div', { class: 'dc-meta' }, [
        el('span', { class: 'badge muted' }, d.hotspotOff ? 'Hotspot OFF' : 'Hotspot ON'),
        el('span', { class: 'badge muted' }, d.quietTimeEnabled ? `Quiet ${d.quietStart}–${d.quietEnd}` : 'Quiet OFF'),
      ]),
    ]));
  }

  // Add-device call-to-action as the last tile (scroll right to see it)
  cards.push(el('div', {
    class: 'device-card enroll',
    role: 'button',
    'aria-label': 'Enroll device',
    onClick: () => enrollmentSheet({ backTo: '/parent/dashboard' }),
  }, [
    el('div', { class: 'enroll-inner' }, [
      el('div', { class: 'enroll-icon' }, iconSquare('qr')),
      el('div', { class: 'enroll-title' }, 'Enroll device'),
      el('div', { class: 'enroll-sub' }, 'Add another child phone'),
    ])
  ]));

  return el('div', { class: 'pager', id: 'devicePager' }, cards);
}

function screenParentDashboard() {
  const device = getDevice();
  const stale = device.lastCheckInMinutes >= 120;

  return {
    nav: navbar({ title: 'Dashboard', rightText: `Signed in as ${state.parentName}` }),
    body: el('div', { class: 'content' }, [
      deviceCarousel(),

      // Inline device details (replaces the old “Policy status” card)
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'hstack', style: 'justify-content:space-between' }, [
          el('div', { class: 'h2' }, 'Device rules'),
          stale ? el('span', { class: 'badge warn' }, 'Check-in stale') : el('span', { class: 'badge good' }, 'Active'),
        ]),
        el('p', { class: 'p' }, `Last seen: ${device.lastCheckInMinutes}m ago`),

        el('div', { class: 'toggle' }, [
          el('div', {}, [
            el('div', { style: 'font-weight:720' }, 'Hotspot OFF'),
            el('div', { class: 'small' }, 'Shortcut turns off hotspot + rotates password')
          ]),
          toggleSwitch(device.hotspotOff, () => { device.hotspotOff = !device.hotspotOff; render(); }),
        ]),

        el('div', { class: 'toggle' }, [
          el('div', {}, [
            el('div', { style: 'font-weight:720' }, 'Quiet Time'),
            el('div', { class: 'small' }, 'Per-device schedule')
          ]),
          toggleSwitch(device.quietTimeEnabled, () => { device.quietTimeEnabled = !device.quietTimeEnabled; render(); }),
        ]),

        device.quietTimeEnabled ? el('div', { class: 'hstack' }, [
          el('div', { style: 'flex:1' }, [
            el('div', { class: 'small' }, 'Start'),
            el('input', { class: 'field', value: device.quietStart, onInput: (e) => { device.quietStart = e.target.value; } })
          ]),
          el('div', { style: 'flex:1' }, [
            el('div', { class: 'small' }, 'End'),
            el('input', { class: 'field', value: device.quietEnd, onInput: (e) => { device.quietEnd = e.target.value; } })
          ]),
        ]) : null,

        el('button', { class: 'btn primary full', onClick: () => alert('Saved (mock)') }, [iconSquare('rules'), 'Save rules']),
      ].filter(Boolean)),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Recent activity'),
        el('div', { class: 'list' }, (device.activity || []).map(a =>
          el('div', { class: 'row', onClick: () => alert('Open activity details (mock)') }, [
            el('div', {}, [
              el('div', { class: 'title' }, a.msg),
              el('div', { class: 'sub' }, a.t)
            ]),
            el('span', { class: 'badge muted' }, 'View')
          ])
        )),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Troubleshooting'),
        el('button', { class: 'btn full', onClick: () => alert('Show troubleshooting (mock)') }, [iconSquare('tool'), 'Shortcut not running']),
        el('button', {
          class: 'btn danger full',
          onClick: () => {
            const ok = confirm(`Remove “${device.name}”? (mock)`);
            if (!ok) return;
            state.devices = state.devices.filter(d => d.id !== device.id);
            if (!state.devices.length) {
              // Keep prototype stable: re-add a placeholder device.
              state.devices = [{
                id: 'dev_1',
                name: 'Child iPhone',
                status: 'SETUP',
                lastCheckInMinutes: 0,
                hotspotOff: true,
                quietTimeEnabled: false,
                quietStart: '22:00',
                quietEnd: '07:00',
                latest: { hotspotOff: 'unknown', rotatePassword: 'unknown' },
                activity: [{ t: 'Now', msg: 'Device added (setup pending)' }],
              }];
            }
            state.selectedDeviceId = state.devices[0].id;
            persist();
            render();
          }
        }, [iconSquare('trash'), 'Remove device']),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Tamper warning'),
        el('p', { class: 'p' }, stale
          ? 'No recent activity — device may be tampered with or automations stopped running.'
          : 'No warning (recent activity).'
        ),
        el('p', { class: 'small' }, 'Troubleshoot: verify automations, Shortcut is present, network access, and Screen Time passcode.'),
      ]),
    ]),
    tabs: bottomTabs('dashboard'),
  };
}

// Devices list removed (everything is handled on Dashboard)
function screenParentDevices() {
  return screenParentDashboard();
}

function screenParentDeviceDetails(deviceId) {
  const d = state.devices.find(x => x.id === deviceId) || getDevice();
  const stale = d.lastCheckInMinutes >= 120;

  return {
    // Prefer returning to the actual previous screen; fall back to Dashboard.
    nav: navbar({ title: d.name, backTo: '/parent/dashboard' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'hstack', style: 'justify-content:space-between' }, [
          el('div', { class: 'h2' }, 'Overview'),
          badgeFor(d.status),
        ]),
        el('p', { class: 'p' }, `Last seen: ${d.lastCheckInMinutes}m ago`),
        stale ? el('div', { class: 'badge warn' }, '⚠️ Stale activity') : el('div', { class: 'badge good' }, 'Recent activity'),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Policy'),
        el('div', { class: 'toggle' }, [
          el('div', {}, [
            el('div', { style: 'font-weight:720' }, 'Hotspot OFF'),
            el('div', { class: 'small' }, 'Shortcut turns off hotspot + rotates password')
          ]),
          toggleSwitch(d.hotspotOff, () => { d.hotspotOff = !d.hotspotOff; render(); }),
        ]),
        el('div', { class: 'toggle' }, [
          el('div', {}, [
            el('div', { style: 'font-weight:720' }, 'Quiet Time'),
            el('div', { class: 'small' }, 'Per-device schedule')
          ]),
          toggleSwitch(d.quietTimeEnabled, () => { d.quietTimeEnabled = !d.quietTimeEnabled; render(); }),
        ]),
        d.quietTimeEnabled ? el('div', { class: 'hstack' }, [
          el('div', { style: 'flex:1' }, [
            el('div', { class: 'small' }, 'Start'),
            el('input', { class: 'field', value: d.quietStart, onInput: (e) => { d.quietStart = e.target.value; } })
          ]),
          el('div', { style: 'flex:1' }, [
            el('div', { class: 'small' }, 'End'),
            el('input', { class: 'field', value: d.quietEnd, onInput: (e) => { d.quietEnd = e.target.value; } })
          ]),
        ]) : null,
        el('button', { class: 'btn primary full', onClick: () => alert('Saved (mock)') }, [iconSquare('rules'), 'Save policy']),
      ].filter(Boolean)),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Recent activity'),
        el('div', { class: 'list' }, d.activity.map(a =>
          el('div', { class: 'row', onClick: () => alert('Open activity details (mock)') }, [
            el('div', {}, [
              el('div', { class: 'title' }, a.msg),
              el('div', { class: 'sub' }, a.t)
            ]),
            el('span', { class: 'badge muted' }, 'View')
          ])
        )),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Troubleshooting'),
        el('button', { class: 'btn full', onClick: () => alert('Show troubleshooting (mock)') }, [iconSquare('tool'), 'Shortcut not running']),
        el('button', { class: 'btn danger full', onClick: () => alert('Remove device (mock)') }, [iconSquare('trash'), 'Remove device']),
      ]),
    ]),
    tabs: bottomTabs('dashboard'),
  };
}

function screenParentSettings() {
  return {
    nav: navbar({ title: 'Settings' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Mode'),
        el('div', { class: 'toggle' }, [
          el('div', {}, [
            el('div', { style: 'font-weight:720' }, 'This is a child phone'),
            el('div', { class: 'small' }, 'Show the child setup experience on this device')
          ]),
          toggleSwitch(state.isChildPhone, () => {
            state.isChildPhone = !state.isChildPhone;
            persist();
            if (state.isChildPhone) route.go('/child/dashboard');
            else render();
          }),
        ]),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Account'),
        el('div', { class: 'kv' }, [ el('div', { class: 'k' }, 'Signed in'), el('div', { class: 'v' }, state.signedIn ? 'Yes' : 'No') ]),
        el('button', {
          class: 'btn danger full',
          onClick: () => {
            state.signedIn = false;
            persist();
            route.go('/');
          }
        }, [iconSquare('logout'), 'Sign out']),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Debug'),
        el('p', { class: 'p' }, 'Static prototype. No server, no push, no background tasks.'),
      ]),
    ]),
    tabs: bottomTabs('settings'),
  };
}

// Legacy route kept for old links; we now land on /child/dashboard.
function screenChildOnboarding() {
  return screenChildDashboard();
}

function screenChildSettings() {
  const c = state.childSetup;
  const paired = c.paired;

  return {
    nav: navbar({ title: 'Settings', backTo: '/child/dashboard' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Mode'),
        el('div', { class: 'toggle' }, [
          el('div', {}, [
            el('div', { style: 'font-weight:720' }, 'This is a child phone'),
            el('div', { class: 'small' }, 'Show the child setup experience on this device')
          ]),
          toggleSwitch(state.isChildPhone, () => {
            state.isChildPhone = !state.isChildPhone;
            persist();
            // If turning OFF child mode while inside child flow, bounce to parent.
            if (!state.isChildPhone) route.go(navState.lastParentRoute || '/parent/dashboard');
            else render();
          }),
        ]),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Pairing'),
        el('p', { class: 'p' }, paired ? 'Paired ✅' : 'Not paired yet.'),
        el('div', { class: 'hstack' }, [
          el('button', {
            class: 'btn primary',
            onClick: () => { c.paired = true; alert('Paired (mock)'); route.go('/child/dashboard'); }
          }, [iconSquare('qr'), paired ? 'Re-scan (mock)' : 'Scan QR (mock)']),
          paired ? el('button', { class: 'btn', onClick: () => { c.paired = false; render(); } }, [iconSquare('unlink'), 'Unpair']) : null,
        ].filter(Boolean)),

        el('div', { class: 'h2', style: 'margin-top:6px' }, 'Or enter pairing code'),
        el('input', {
          class: 'field',
          placeholder: 'e.g. ABCD-1234',
          value: c._pairCode || '',
          onInput: (e) => { c._pairCode = e.target.value; }
        }),
        el('button', {
          class: 'btn full',
          onClick: () => {
            if ((c._pairCode || '').trim().length < 4) return alert('Enter a code');
            c.paired = true;
            alert('Paired (mock)');
            route.go('/child/dashboard');
          }
        }, [iconSquare('shortcut'), 'Pair']),
        el('p', { class: 'small' }, 'Pairing enables the Shortcut to fetch policy (hotspot off + quiet time).'),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Exit'),
        el('p', { class: 'p' }, 'When you’re done configuring the child phone, exit back to the parent app.'),
        el('button', {
          class: 'btn primary full',
          onClick: () => route.go(navState.lastParentRoute || '/parent/dashboard'),
        }, [iconSquare('home'), 'Exit child setup']),
      ]),
    ]),
  };
}

function screenChildScreenTime() {
  const c = state.childSetup;
  return {
    nav: navbar({ title: 'Screen Time lock', backTo: '/child/dashboard' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Shield apps'),
        el('p', { class: 'p' }, 'Real app uses Apple APIs (FamilyControls + ManagedSettings). Here it’s a mock selection.'),
        el('div', { class: 'list' }, [
          el('div', { class: 'row', onClick: () => { c._shieldSettings = !c._shieldSettings; render(); } }, [
            el('div', {}, [el('div', { class: 'title' }, 'Settings'), el('div', { class: 'sub' }, 'Recommended')]),
            el('span', { class: `badge ${c._shieldSettings ? 'good' : 'muted'}` }, c._shieldSettings ? 'Selected' : 'Not')
          ]),
          el('div', { class: 'row', onClick: () => { c._shieldShortcuts = !c._shieldShortcuts; render(); } }, [
            el('div', {}, [el('div', { class: 'title' }, 'Shortcuts'), el('div', { class: 'sub' }, 'Recommended')]),
            el('span', { class: `badge ${c._shieldShortcuts ? 'good' : 'muted'}` }, c._shieldShortcuts ? 'Selected' : 'Not')
          ]),
        ]),
        el('button', {
          class: 'btn primary full',
          onClick: () => {
            c.shieldingApplied = true;
            alert('Shielding applied (mock)');
            route.go('/child/dashboard');
          }
        }, [iconSquare('shield'), 'Apply shielding']),
        el('p', { class: 'small' }, 'Reminder: set a Screen Time passcode in Settings (apps can’t set it for you).'),
      ]),
    ]),
  };
}

function stepRow(done, title, sub, onToggle) {
  return el('div', { class: 'row', onClick: onToggle }, [
    el('div', {}, [
      el('div', { class: 'title' }, title),
      el('div', { class: 'sub' }, sub),
    ]),
    el('span', { class: `badge ${done ? 'good' : 'muted'}` }, done ? 'Done' : 'Todo'),
  ]);
}

function screenChildLocked() {
  return {
    nav: navbar({ title: 'Locked', backTo: '/child/dashboard' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'hero' }, [
        el('div', { class: 'hero-top' }, [
          el('div', {}, [
            el('h1', { class: 'hero-title' }, 'Setup complete'),
            el('p', { class: 'hero-sub' }, 'Hand the phone back to the child. This screen stays on.'),
          ]),
          el('span', { class: 'badge good' }, 'Ready')
        ]),
      ]),
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'What the child should do'),
        el('div', { class: 'list' }, [
          el('div', { class: 'row' }, [el('div', {}, [el('div', { class: 'title' }, 'Don’t change settings'), el('div', { class: 'sub' }, 'Shortcuts + Screen Time must stay enabled')])]),
          el('div', { class: 'row' }, [el('div', {}, [el('div', { class: 'title' }, 'Leave this app open'), el('div', { class: 'sub' }, 'If asked, tap “Always Allow” for automations')])]),
        ]),
      ]),
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, 'Parent only'),
        el('p', { class: 'p' }, 'If you need to make changes, go back to the parent app.'),
        el('button', {
          class: 'btn primary full',
          onClick: () => route.go(navState.lastParentRoute || '/parent/dashboard'),
        }, [iconSquare('home'), 'Return to parent app']),
      ]),
    ]),
  };
}

function screenChildDashboard() {
  const c = state.childSetup;
  return {
    nav: navbar({ title: 'Dashboard', backTo: '/child/settings' }),
    body: el('div', { class: 'content' }, [
      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, '1) Pair device'),
        el('p', { class: 'p' }, c.paired ? 'Paired ✅' : 'Not paired yet.'),
        el('div', { class: 'hstack' }, [
          el('button', { class: 'btn primary', onClick: () => route.go('/child/pair') }, [iconSquare('qr'), c.paired ? 'View pairing' : 'Start pairing']),
          c.paired ? el('button', { class: 'btn', onClick: () => { c.paired = false; render(); } }, [iconSquare('unlink'), 'Unpair']) : null,
        ].filter(Boolean)),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, '2) Shortcut'),
        stepRow(c.shortcutInstalled, 'Install Shortcut', 'Open link and add it', () => { c.shortcutInstalled = !c.shortcutInstalled; render(); }),
        stepRow(c.appIntentAdded, 'Add “Get Hotspot Config”', 'Ensure the first step is the App Intent', () => { c.appIntentAdded = !c.appIntentAdded; render(); }),
        el('button', { class: 'btn full', onClick: () => alert('Open Shortcut link (mock)') }, [iconSquare('shortcut'), 'Open Shortcut link']),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, '3) Automations'),
        stepRow(c.automationsEnabled, 'Enable automations', 'Battery + time-of-day triggers', () => { c.automationsEnabled = !c.automationsEnabled; render(); }),
      ]),

      el('div', { class: 'card vstack' }, [
        el('div', { class: 'h2' }, '4) Screen Time lock'),
        el('p', { class: 'p' }, 'Authorize in-app, set a passcode in Settings, then shield apps.'),
        stepRow(c.screenTimeAuthorized, 'Authorize Screen Time', 'Grant permission in-app (FamilyControls)', () => { c.screenTimeAuthorized = !c.screenTimeAuthorized; render(); }),
        stepRow(c.screenTimePasscodeSet, 'Set Screen Time passcode', 'Parent sets passcode in Settings', () => { c.screenTimePasscodeSet = !c.screenTimePasscodeSet; render(); }),
        el('button', { class: 'btn primary full', onClick: () => route.go('/child/screentime') }, [iconSquare('shield'), 'Select apps to shield']),
      ]),

      el('div', { class: 'card vstack' }, [
        el('button', { class: 'btn full', onClick: () => route.go('/child/locked') }, [iconSquare('check'), 'Finish setup']),
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
  // Devices screen removed; route back to Dashboard.
  if (p === '/parent/devices') return screenParentDashboard();
  if (p.startsWith('/parent/device/')) return screenParentDeviceDetails(p.split('/').pop());
  if (p === '/parent/settings') return screenParentSettings();

  // Child setup flow
  if (p === '/child/onboarding') return screenChildOnboarding();
  if (p === '/child/dashboard') return screenChildDashboard();
  if (p === '/child/settings') return screenChildSettings();
  // Legacy child routes redirect into the new structure
  if (p === '/child/checklist') return screenChildDashboard();
  if (p === '/child/pair') return screenChildSettings();
  if (p === '/child/screentime') return screenChildScreenTime();
  if (p === '/child/locked') return screenChildLocked();

  return {
    nav: navbar({ title: 'Not Found', backTo: '/' }),
    body: el('div', { class: 'content' }, el('div', { class: 'card' }, 'Unknown route')),
  };
}

function activeTabForPath(p) {
  // Hide tab bars during landing + onboarding/auth (iOS convention)
  if (p === '/' || p === '') return null;
  if (p === '/parent/onboarding' || p === '/parent/signin') return null;

  if (p.startsWith('/parent/')) {
    if (!state.signedIn) return null;
    if (p === '/parent/dashboard') return 'dashboard';
    if (p === '/parent/devices' || p.startsWith('/parent/device/')) return 'dashboard';
    if (p === '/parent/settings') return 'settings';
    return 'dashboard';
  }

  if (p.startsWith('/child/')) {
    if (p === '/child/locked') return null;
    if (p === '/child/dashboard') return 'dashboard';
    if (p === '/child/settings') return 'settings';
    if (p === '/child/screentime') return 'dashboard';
    // Legacy routes → dashboard
    if (p === '/child/onboarding' || p === '/child/checklist' || p === '/child/pair') return 'dashboard';
    return 'dashboard';
  }

  return null;
}

function render() {
  const s = resolveScreen();
  const p = route.path || '/';

  appRoot.innerHTML = '';
  appRoot.appendChild(s.nav);
  appRoot.appendChild(s.body);

  const active = activeTabForPath(p);
  const tabsNode = s.tabs || (active ? bottomTabs(active) : null);
  if (tabsNode) appRoot.appendChild(tabsNode);
}

window.addEventListener('hashchange', () => {
  // Close any open sheet on navigation to prevent stacking.
  closeSheet();

  // Keep mode in sync with the current route so the correct bottom bar shows.
  const p = route.path || '/';
  if (p.startsWith('/parent/')) state.mode = 'parent';
  if (p.startsWith('/child/')) state.mode = 'childsetup';
  persist();

  navTrack(p);
  render();
});

// Initial route
if (!location.hash) location.hash = '#/';
{
  const p = route.path || '/';
  if (p.startsWith('/parent/')) state.mode = 'parent';
  if (p.startsWith('/child/')) state.mode = 'childsetup';
  persist();
  navTrack(p);
}
render();
