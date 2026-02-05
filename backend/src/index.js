import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import Database from 'better-sqlite3';
import { z } from 'zod';

function env(name, fallback = undefined) {
  const v = process.env[name];
  if (v == null || v === '') return fallback;
  return v;
}

// On Render (and most PaaS), you must bind to 0.0.0.0 so the platform can route traffic.
const HOST = env('HOST', '0.0.0.0');
const PORT = Number(env('PORT', '3003'));
const DATABASE_PATH = env('DATABASE_PATH', path.resolve('data/hotspot.sqlite3'));
const ADMIN_TOKEN = env('ADMIN_TOKEN', 'change-me');
const MAX_SKEW_MS = Number(env('MAX_SKEW_MS', String(5 * 60 * 1000)));
const LOG_REQUEST_BODIES = env('LOG_REQUEST_BODIES', '0') === '1';

fs.mkdirSync(path.dirname(DATABASE_PATH), { recursive: true });
const db = new Database(DATABASE_PATH);
db.pragma('journal_mode = WAL');

// Schema
// Notes:
// - devices are "owned" by a parent account keyed by admin token for now (MVP).
// - later we can add real users/auth.
function tableHasColumn(table, column) {
  const cols = db.prepare(`PRAGMA table_info(${table})`).all();
  return cols.some(c => c.name === column);
}

db.exec(`
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  device_token TEXT NOT NULL UNIQUE,
  device_secret TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_seen_at TEXT
);

CREATE TABLE IF NOT EXISTS device_policies (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE,
  enforce INTEGER NOT NULL DEFAULT 1,
  set_hotspot_off INTEGER NOT NULL DEFAULT 1,
  rotate_password INTEGER NOT NULL DEFAULT 1,
  quiet_start TEXT,
  quiet_end TEXT,
  tz TEXT,
  gap_ms INTEGER NOT NULL DEFAULT 7200000,
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS device_events (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  ts INTEGER NOT NULL,
  trigger TEXT NOT NULL,
  shortcut_version TEXT,
  actions_attempted TEXT,
  result_ok INTEGER NOT NULL DEFAULT 1,
  result_errors TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY(device_id) REFERENCES devices(id) ON DELETE CASCADE
);

-- Pairing codes for public Shortcut/app enrollment
CREATE TABLE IF NOT EXISTS pairing_codes (
  code TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at INTEGER NOT NULL,
  redeemed_at INTEGER,
  redeemed_ip TEXT,
  FOREIGN KEY(device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_devices_created ON devices(created_at);
CREATE INDEX IF NOT EXISTS idx_device_events_device ON device_events(device_id);
CREATE INDEX IF NOT EXISTS idx_device_events_ts ON device_events(ts);
CREATE INDEX IF NOT EXISTS idx_pairing_codes_device ON pairing_codes(device_id);
CREATE INDEX IF NOT EXISTS idx_pairing_codes_expires ON pairing_codes(expires_at);
`);

// Lightweight migration for existing DBs
if (db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='device_policies'").get()) {
  if (!tableHasColumn('device_policies', 'gap_ms')) {
    db.exec('ALTER TABLE device_policies ADD COLUMN gap_ms INTEGER NOT NULL DEFAULT 7200000');
  }
}

const app = express();
app.disable('x-powered-by');
app.use(helmet({ crossOriginResourcePolicy: false, contentSecurityPolicy: false }));
app.use(morgan('dev'));

// Raw body capture for HMAC auth
app.use(
  express.json({
    limit: '1mb',
    verify: (req, res, buf) => {
      req.rawBody = buf?.toString('utf8') || '';
    }
  })
);

// For Apple "form_post" return mode and other urlencoded callbacks.
app.use(express.urlencoded({ extended: false }));

// Optional request body logging (debugging). Never log Authorization headers.
if (LOG_REQUEST_BODIES) {
  app.use((req, res, next) => {
    if (req.method === 'POST') {
      // Try to log parsed JSON body when available, otherwise rawBody.
      let body = req.body;
      if (body == null || (typeof body === 'object' && Object.keys(body).length === 0)) {
        body = req.rawBody || null;
      }

      // Redact common sensitive fields.
      const redact = v => {
        if (v == null) return v;
        const s = String(v);
        if (s.length <= 8) return '***';
        return s.slice(0, 4) + '…' + s.slice(-4);
      };

      let safe = body;
      try {
        if (body && typeof body === 'object') {
          safe = { ...body };
          if ('deviceSecret' in safe) safe.deviceSecret = redact(safe.deviceSecret);
          if ('device_secret' in safe) safe.device_secret = redact(safe.device_secret);
        }
      } catch {
        // ignore
      }

      const out = typeof safe === 'string' ? safe.slice(0, 1000) : safe;
      console.log(`[hotspot] POST ${req.path} body=`, out);
    }
    return next();
  });
}

const id = () => crypto.randomUUID();

function randomPairingCode() {
  // Human-friendly-ish: 10 chars base32-ish, uppercase, no padding.
  // (Not cryptographically short-code-safe against brute force on a huge scale,
  // but fine for MVP when combined with short expiry + rate limiting later.)
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // avoid 0/O/1/I
  const bytes = crypto.randomBytes(10);
  let out = '';
  for (let i = 0; i < bytes.length; i++) out += alphabet[bytes[i] % alphabet.length];
  return out;
}

function normalizeHex(input) {
  return String(input || '').trim().toLowerCase();
}

function hmacSha256Hex(secret, message) {
  return crypto.createHmac('sha256', secret).update(message).digest('hex');
}

function timingSafeEqualHex(a, b) {
  const aa = Buffer.from(normalizeHex(a), 'hex');
  const bb = Buffer.from(normalizeHex(b), 'hex');
  if (aa.length !== bb.length) return false;
  return crypto.timingSafeEqual(aa, bb);
}

function shortcutMessageToSign({ ts, method, path, body }) {
  return `${ts}\n${method.toUpperCase()}\n${path}\n${body || ''}`;
}

function requireShortcutAuth(req, res, next) {
  try {
    const deviceToken = String(req.header('X-Device-Token') || '').trim();

    // New (Shortcut-friendly): bearer token == device_secret
    const bearer = String(req.header('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
    if (bearer) {
      const device = db
        .prepare('SELECT id, device_token FROM devices WHERE device_secret = ?')
        .get(bearer);
      if (!device) return res.status(401).json({ error: 'unauthorized' });

      // Optional sanity check if client also provided X-Device-Token
      if (deviceToken && deviceToken !== device.device_token) return res.status(401).json({ error: 'unauthorized' });

      req.shortcut = { deviceId: device.id, deviceToken: device.device_token };
      return next();
    }

    // Legacy: HMAC auth
    const ts = String(req.header('X-TS') || '').trim();
    const sig = String(req.header('X-Signature') || '').trim();

    if (!deviceToken || !ts || !sig) return res.status(401).json({ error: 'unauthorized' });

    const tsNum = Number(ts);
    if (!Number.isFinite(tsNum)) return res.status(401).json({ error: 'unauthorized' });
    if (Math.abs(Date.now() - tsNum) > MAX_SKEW_MS) return res.status(401).json({ error: 'unauthorized' });

    const device = db.prepare('SELECT id, device_secret FROM devices WHERE device_token = ?').get(deviceToken);
    if (!device) return res.status(401).json({ error: 'unauthorized' });

    const rawBody = req.rawBody || '';
    const msg = shortcutMessageToSign({ ts, method: req.method, path: req.path, body: rawBody });
    const expected = hmacSha256Hex(device.device_secret, msg);
    if (!timingSafeEqualHex(expected, sig)) return res.status(401).json({ error: 'unauthorized' });

    req.shortcut = { deviceId: device.id, deviceToken };
    return next();
  } catch {
    return res.status(401).json({ error: 'unauthorized' });
  }
}

function requireAdmin(req, res, next) {
  const token = String(req.header('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
  if (!token || token !== ADMIN_TOKEN) return res.status(401).json({ error: 'unauthorized' });
  return next();
}

app.get('/healthz', (req, res) => res.json({ ok: true }));

// --- Sign in with Apple (Web) ---
const APPLE_TEAM_ID = env('APPLE_TEAM_ID');
const APPLE_KEY_ID = env('APPLE_KEY_ID');
const APPLE_SERVICE_ID = env('APPLE_SERVICE_ID');
const APPLE_REDIRECT_URI = env('APPLE_REDIRECT_URI', `https://hotspot-api-ux32.onrender.com/auth/apple/callback`);
const APPLE_PRIVATE_KEY = env('APPLE_PRIVATE_KEY');
const APPLE_PRIVATE_KEY_PATH = env('APPLE_PRIVATE_KEY_PATH');

function base64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function appleLoadPrivateKey() {
  if (APPLE_PRIVATE_KEY) return APPLE_PRIVATE_KEY;
  if (APPLE_PRIVATE_KEY_PATH) return fs.readFileSync(APPLE_PRIVATE_KEY_PATH, 'utf8');
  return null;
}

function appleMakeClientSecret() {
  if (!APPLE_TEAM_ID || !APPLE_KEY_ID || !APPLE_SERVICE_ID) {
    throw new Error('missing APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_SERVICE_ID');
  }
  const keyPem = appleLoadPrivateKey();
  if (!keyPem) throw new Error('missing APPLE_PRIVATE_KEY or APPLE_PRIVATE_KEY_PATH');

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: APPLE_KEY_ID, typ: 'JWT' };
  const payload = {
    iss: APPLE_TEAM_ID,
    iat: now,
    exp: now + 60 * 60 * 24 * 180, // max 6 months
    aud: 'https://appleid.apple.com',
    sub: APPLE_SERVICE_ID
  };

  const encodedHeader = base64url(JSON.stringify(header));
  const encodedPayload = base64url(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const sign = crypto.createSign('sha256');
  sign.update(signingInput);
  sign.end();

  // Apple expects ES256; Node will infer ECDSA from the EC private key.
  // Use ieee-p1363 so the signature is raw R||S as required by JWS.
  const signature = sign.sign({ key: keyPem, dsaEncoding: 'ieee-p1363' });
  return `${signingInput}.${base64url(signature)}`;
}

async function appleTokenExchange(code) {
  const secret = appleMakeClientSecret();
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: APPLE_REDIRECT_URI,
    client_id: APPLE_SERVICE_ID,
    client_secret: secret
  });

  const res = await fetch('https://appleid.apple.com/auth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body
  });

  const txt = await res.text();
  let json;
  try {
    json = JSON.parse(txt);
  } catch {
    json = { raw: txt };
  }

  if (!res.ok) {
    const err = json?.error || res.status;
    throw new Error(`apple token exchange failed: ${err}`);
  }

  return json;
}

function randomState() {
  return crypto.randomBytes(16).toString('hex');
}

// Start web auth: redirects user to Apple.
app.get('/auth/apple/start', (req, res) => {
  try {
    if (!APPLE_SERVICE_ID) return res.status(500).json({ error: 'missing APPLE_SERVICE_ID' });

    const state = randomState();
    // Minimal state storage: store in a short-lived cookie.
    // (Good enough for MVP; later we should store server-side.)
    res.setHeader('Set-Cookie', [
      `apple_oauth_state=${state}; Max-Age=${10 * 60}; Path=/; HttpOnly; SameSite=Lax; Secure`
    ]);

    const params = new URLSearchParams({
      response_type: 'code',
      response_mode: 'form_post',
      client_id: APPLE_SERVICE_ID,
      redirect_uri: APPLE_REDIRECT_URI,
      scope: 'name email',
      state
    });

    const url = `https://appleid.apple.com/auth/authorize?${params.toString()}`;
    return res.redirect(url);
  } catch (e) {
    return res.status(400).json({ ok: false, error: String(e?.message || e) });
  }
});

// For now, we expose a minimal callback that exchanges the code and returns tokens.
// Next step is to validate id_token, create a session, and redirect back to the app.
app.all('/auth/apple/callback', async (req, res) => {
  try {
    const state = String(req.body?.state || req.query?.state || '').trim();
    const cookieHeader = String(req.headers.cookie || '');
    const cookies = Object.fromEntries(
      cookieHeader
        .split(';')
        .map(p => p.trim())
        .filter(Boolean)
        .map(p => {
          const i = p.indexOf('=');
          if (i === -1) return [p, ''];
          return [p.slice(0, i), decodeURIComponent(p.slice(i + 1))];
        })
    );
    const expectedState = String(cookies.apple_oauth_state || '').trim();
    if (!state || !expectedState || state !== expectedState) {
      return res.status(400).json({ error: 'invalid state' });
    }

    const code = String(req.body?.code || req.query?.code || '').trim();
    if (!code) return res.status(400).json({ error: 'missing code' });

    const out = await appleTokenExchange(code);
    return res.json({ ok: true, apple: out });
  } catch (e) {
    return res.status(400).json({ ok: false, error: String(e?.message || e) });
  }
});

// When running behind ngrok for testing, we want ONLY the Shortcut endpoints public.
// ngrok forwards requests from the public internet to localhost, so IP-based checks won't help.
// Instead, we gate admin surfaces by Host.
function isLocalHostHeader(host) {
  const h = String(host || '').toLowerCase();
  return h.startsWith('127.0.0.1') || h.startsWith('localhost');
}

app.use((req, res, next) => {
  const host = req.headers.host;
  const localHost = isLocalHostHeader(host);

  // Allow Shortcut endpoints + healthz + auth callbacks from anywhere.
  // HMAC auth applies to /policy and /events.
  // /pair is public but one-time and short-lived (pairing code).
  if (
    req.path === '/healthz' ||
    req.path === '/policy' ||
    req.path === '/events' ||
    req.path === '/pair' ||
    req.path.startsWith('/auth/apple')
  )
    return next();

  // Block admin surfaces when accessed via a non-local Host (e.g., ngrok public URL).
  if (!localHost && (req.path === '/admin' || req.path.startsWith('/api/'))) {
    return res.status(404).type('text').send('not found');
  }

  return next();
});

// --- Minimal admin UI (temporary) ---
// Visit: http://127.0.0.1:3003/admin
// It uses ADMIN_TOKEN in the browser via "Bearer <token>" (stored in localStorage).
app.get('/admin', (req, res) => {
  res.type('html').send(`<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Hotspot Admin</title>
  <style>
    body{font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial; margin:24px; max-width:960px}
    input,button{font-size:14px; padding:8px}
    table{border-collapse:collapse; width:100%; margin-top:16px}
    th,td{border:1px solid #ddd; padding:8px; text-align:left; vertical-align:top}
    th{background:#f6f6f6}
    code{font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace}
    .row{display:flex; gap:8px; flex-wrap:wrap; align-items:center}
    .muted{color:#666}
  </style>
</head>
<body>
  <h1>Hotspot Admin</h1>

  <div class="row">
    <label>Admin token:</label>
    <input id="token" type="password" placeholder="paste ADMIN_TOKEN" size="44" />
    <button id="save">Save</button>
    <span id="saveStatus" class="muted"></span>
    <span class="muted">stored in this browser’s localStorage</span>
  </div>

  <hr />

  <h2>Create device</h2>
  <div class="row">
    <input id="name" placeholder="Device name" size="28" />
    <button id="create">Create</button>
  </div>
  <pre id="created"></pre>

  <h2>Devices</h2>
  <button id="refresh">Refresh</button>
  <div id="status" class="muted"></div>
  <table id="tbl">
    <thead>
      <tr>
        <th>Name</th>
        <th>Token</th>
        <th>Enforce</th>
        <th>Gap (min)</th>
        <th>Quiet start</th>
        <th>Quiet end</th>
        <th>TZ</th>
        <th>Last event</th>
        <th>Gap?</th>
        <th>Actions</th>
        <th>Pairing</th>
      </tr>
    </thead>
    <tbody></tbody>
  </table>

  <h3>Device events</h3>
  <div class="muted">Select “Events” for a device to load last 200 entries.</div>
  <pre id="events"></pre>

<script>
  const $ = (id)=>document.getElementById(id);
  const tokenKey='hotspot_admin_token';
  $('token').value = localStorage.getItem(tokenKey)||'';

  function authHeaders(){
    const t = $('token').value.trim();
    return { 'Authorization': 'Bearer ' + t };
  }

  async function api(path, opts={}){
    const res = await fetch(path, {
      ...opts,
      headers: { 'Content-Type':'application/json', ...(opts.headers||{}), ...authHeaders() }
    });
    const txt = await res.text();
    let data; try{ data = JSON.parse(txt); }catch{ data = { raw: txt }; }
    if(!res.ok) throw new Error(res.status + ' ' + (data?.error||'error'));
    return data;
  }

  $('save').onclick = ()=>{
    localStorage.setItem(tokenKey, $('token').value.trim());
    $('saveStatus').textContent = 'saved';
    setTimeout(()=>{ $('saveStatus').textContent=''; }, 1500);
  };

  $('create').onclick = async ()=>{
    $('created').textContent='';
    const name = $('name').value.trim() || undefined;
    try{
      const out = await api('/api/devices', { method:'POST', body: JSON.stringify({ name }) });
      $('created').textContent = 'Save these in your Shortcut once (secret is not returned again):\\n\\n' + JSON.stringify(out, null, 2);
      await refresh();
    }catch(e){
      $('created').textContent = String(e);
    }
  };

  async function refresh(){
    $('status').textContent='Loading...';
    $('events').textContent='';
    const tbody = $('tbl').querySelector('tbody');
    tbody.innerHTML='';
    try{
      const dash = await api('/api/dashboard');

      for(const d of dash.devices){
        const tr=document.createElement('tr');

        const gapMin = Math.round((d.gapMs||7200000) / 60000);
        const quietStart = d.quietHours && d.quietHours.start ? d.quietHours.start : '';
        const quietEnd = d.quietHours && d.quietHours.end ? d.quietHours.end : '';
        const tz = d.quietHours && d.quietHours.tz ? d.quietHours.tz : '';

        tr.innerHTML =
          '<td>' + escapeHtml(d.name||'') + '</td>' +
          '<td><code>' + escapeHtml(d.device_token) + '</code></td>' +
          '<td><input type="checkbox" class="enforce" ' + (d.enforce ? 'checked' : '') + ' /></td>' +
          '<td><input class="gapMin" size="6" value="' + escapeHtml(String(gapMin)) + '" /></td>' +
          '<td><input class="quietStart" size="6" placeholder="HH:MM" value="' + escapeHtml(quietStart) + '" /></td>' +
          '<td><input class="quietEnd" size="6" placeholder="HH:MM" value="' + escapeHtml(quietEnd) + '" /></td>' +
          '<td><input class="tz" size="18" placeholder="Europe/Paris" value="' + escapeHtml(tz) + '" /></td>' +
          '<td>' + escapeHtml(d.last_event_at||'') + '</td>' +
          '<td>' + (d.gap ? '<b>YES</b>' : 'no') + '</td>' +
          '<td>' +
            '<button class="saveRow">Save</button> ' +
            '<button class="eventsRow">Events</button>' +
          '</td>' +
          '<td>' +
            '<button class="pairRow">Pair code</button> ' +
            '<span class="pairOut" style="font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"></span>' +
          '</td>';

        tr.querySelector('.saveRow').onclick = async ()=>{
          const enforce = tr.querySelector('.enforce').checked;
          const gapMinutes = Number(String(tr.querySelector('.gapMin').value||'').trim());
          const quietStartVal = String(tr.querySelector('.quietStart').value||'').trim();
          const quietEndVal = String(tr.querySelector('.quietEnd').value||'').trim();
          const tzVal = String(tr.querySelector('.tz').value||'').trim();

          const patch = { enforce };
          if (Number.isFinite(gapMinutes) && gapMinutes > 0) patch.gapMinutes = gapMinutes;
          patch.quietStart = quietStartVal ? quietStartVal : null;
          patch.quietEnd = quietEndVal ? quietEndVal : null;
          patch.tz = tzVal ? tzVal : null;

          tr.style.opacity = '0.6';
          try{
            await api('/api/devices/' + d.id + '/policy', { method:'PATCH', body: JSON.stringify(patch) });
          }finally{
            tr.style.opacity = '1';
          }
          await refresh();
        };

        tr.querySelector('.eventsRow').onclick = async ()=>{
          $('events').textContent = 'Loading...';
          try{
            const out = await api('/api/devices/' + d.id + '/events');
            $('events').textContent = JSON.stringify(out, null, 2);
          }catch(e){
            $('events').textContent = String(e);
          }
        };

        tr.querySelector('.pairRow').onclick = async ()=>{
          const outEl = tr.querySelector('.pairOut');
          outEl.textContent = '...';
          try{
            const out = await api('/api/devices/' + d.id + '/pairing-code', { method:'POST', body: JSON.stringify({ ttlMinutes: 10 }) });
            const exp = out.expiresAt ? new Date(out.expiresAt).toISOString() : '';
            outEl.textContent = out.code + (exp ? (' (exp ' + exp + ')') : '');
          }catch(e){
            outEl.textContent = String(e);
          }
        };

        tbody.appendChild(tr);
      }

      $('status').textContent = 'Devices: ' + dash.devices.length;
    }catch(e){
      $('status').textContent = String(e);
    }
  }

  function escapeHtml(s){
    return String(s).replace(/[&<>"']/g, c => ({
      '&':'&amp;',
      '<':'&lt;',
      '>':'&gt;',
      '"':'&quot;',
      "'":'&#39;'
    }[c]));
  }

  $('refresh').onclick = refresh;
  refresh();
</script>
</body>
</html>`);
});

// --- Shortcut endpoints ---
app.get('/policy', requireShortcutAuth, (req, res) => {
  const deviceId = req.shortcut.deviceId;
  db.prepare("UPDATE devices SET last_seen_at = datetime('now') WHERE id = ?").run(deviceId);

  const pol = db
    .prepare(
      `
      SELECT enforce, set_hotspot_off, rotate_password, quiet_start, quiet_end, tz
      FROM device_policies
      WHERE device_id = ?
      `
    )
    .get(deviceId);

  const out = {
    enforce: pol ? !!pol.enforce : true,
    actions: {
      setHotspotOff: pol ? !!pol.set_hotspot_off : true,
      rotatePassword: pol ? !!pol.rotate_password : true
    },
    quietHours:
      pol && (pol.quiet_start || pol.quiet_end || pol.tz)
        ? { start: pol.quiet_start || null, end: pol.quiet_end || null, tz: pol.tz || null }
        : null
  };

  res.json(out);
});

app.post('/events', requireShortcutAuth, (req, res, next) => {
  try {
    const deviceId = req.shortcut.deviceId;
    db.prepare("UPDATE devices SET last_seen_at = datetime('now') WHERE id = ?").run(deviceId);

    const schema = z.object({
      ts: z.number().int().min(0),
      trigger: z.string().min(1).max(100),
      shortcutVersion: z.string().max(50).optional(),
      actionsAttempted: z.array(z.string().max(50)).optional().default([]),
      result: z
        .object({
          ok: z.boolean().optional().default(true),
          errors: z.array(z.string().max(500)).optional().default([])
        })
        .optional()
        .default({ ok: true, errors: [] })
    });

    const body = schema.parse(req.body);

    db.prepare(
      `
      INSERT INTO device_events (id, device_id, ts, trigger, shortcut_version, actions_attempted, result_ok, result_errors)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `
    ).run(
      id(),
      deviceId,
      body.ts,
      body.trigger,
      body.shortcutVersion || null,
      JSON.stringify(body.actionsAttempted || []),
      body.result?.ok ? 1 : 0,
      JSON.stringify(body.result?.errors || [])
    );

    res.status(201).json({ ok: true });
  } catch (e) {
    next(e);
  }
});

// --- Public pairing (for the one-app flow) ---
// Parent creates a short-lived pairing code (admin-auth), then the child app redeems it here.
app.post('/pair', (req, res, next) => {
  try {
    const schema = z.object({
      code: z.string().min(4).max(32),
      name: z.string().max(200).optional()
    });
    const { code, name } = schema.parse(req.body);

    const now = Date.now();
    const row = db
      .prepare(
        `
        SELECT code, device_id, expires_at, redeemed_at
        FROM pairing_codes
        WHERE code = ?
        `
      )
      .get(code.trim().toUpperCase());

    if (!row) return res.status(404).json({ error: 'invalid_code' });
    if (row.redeemed_at != null) return res.status(409).json({ error: 'already_redeemed' });
    if (Number(row.expires_at) < now) return res.status(410).json({ error: 'expired_code' });

    const device = db
      .prepare('SELECT id, name, device_token, device_secret FROM devices WHERE id = ?')
      .get(row.device_id);
    if (!device) return res.status(404).json({ error: 'invalid_code' });

    const tx = db.transaction(() => {
      db.prepare('UPDATE pairing_codes SET redeemed_at = ?, redeemed_ip = ? WHERE code = ?').run(
        now,
        String(req.ip || ''),
        row.code
      );

      if (name && String(name).trim()) {
        db.prepare('UPDATE devices SET name = ? WHERE id = ?').run(String(name).trim(), device.id);
      }
    });
    tx();

    // Return device credentials to the child app ONCE.
    res.json({
      deviceId: device.id,
      name: name && String(name).trim() ? String(name).trim() : device.name,
      deviceToken: device.device_token,
      deviceSecret: device.device_secret
    });
  } catch (e) {
    next(e);
  }
});

// --- Admin endpoints (temporary, for parent app / dashboard prototyping) ---
function parseHHMM(s) {
  if (s == null) return null;
  const m = String(s).trim().match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  const hh = Number(m[1]);
  const mm = Number(m[2]);
  if (!Number.isFinite(hh) || !Number.isFinite(mm) || hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;
  return hh * 60 + mm;
}

function getMinutesInTzNow(tz) {
  // Returns minutes since midnight in the given IANA TZ.
  // If tz is invalid, falls back to local time.
  const d = new Date();
  if (!tz) return d.getHours() * 60 + d.getMinutes();
  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: tz,
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).formatToParts(d);
    const hh = Number(parts.find(p => p.type === 'hour')?.value);
    const mm = Number(parts.find(p => p.type === 'minute')?.value);
    if (!Number.isFinite(hh) || !Number.isFinite(mm)) throw new Error('bad parts');
    return hh * 60 + mm;
  } catch {
    return d.getHours() * 60 + d.getMinutes();
  }
}

function isWithinQuietHours({ quietStart, quietEnd, tz }) {
  const s = parseHHMM(quietStart);
  const e = parseHHMM(quietEnd);
  if (s == null || e == null) return false;

  const nowMin = getMinutesInTzNow(tz);
  if (s === e) return true; // 24h quiet

  // Range can cross midnight.
  if (s < e) return nowMin >= s && nowMin < e;
  return nowMin >= s || nowMin < e;
}

// "dashboard" summary (gap heuristic + quiet hours)
app.get('/api/dashboard', requireAdmin, (req, res) => {
  const rows = db
    .prepare(
      `
      SELECT
        d.id,
        d.name,
        d.device_token,
        d.created_at,
        d.last_seen_at,
        MAX(e.ts) AS last_event_ts,
        p.enforce AS enforce,
        p.quiet_start AS quiet_start,
        p.quiet_end AS quiet_end,
        p.tz AS tz,
        p.gap_ms AS gap_ms
      FROM devices d
      LEFT JOIN device_events e ON e.device_id = d.id
      LEFT JOIN device_policies p ON p.device_id = d.id
      GROUP BY d.id
      ORDER BY d.created_at DESC
      `
    )
    .all();

  const now = Date.now();
  const devices = rows.map(r => {
    const lastEventTs = r.last_event_ts != null ? Number(r.last_event_ts) : null;
    const gapMs = r.gap_ms != null ? Number(r.gap_ms) : 7200000;

    const enforce = r.enforce == null ? true : !!r.enforce;
    const inQuiet = enforce ? isWithinQuietHours({ quietStart: r.quiet_start, quietEnd: r.quiet_end, tz: r.tz }) : false;
    const shouldBeRunning = enforce && !inQuiet;

    const gap = shouldBeRunning
      ? (lastEventTs == null ? true : now - lastEventTs > gapMs)
      : false;

    return {
      id: r.id,
      name: r.name,
      device_token: r.device_token,
      created_at: r.created_at,
      last_seen_at: r.last_seen_at,
      last_event_ts: lastEventTs,
      last_event_at: lastEventTs ? new Date(lastEventTs).toISOString() : null,
      enforce,
      quietHours: (r.quiet_start || r.quiet_end || r.tz) ? { start: r.quiet_start || null, end: r.quiet_end || null, tz: r.tz || null } : null,
      inQuietHours: inQuiet,
      shouldBeRunning,
      gapMs,
      gap
    };
  });

  res.json({ devices });
});

app.get('/api/devices', requireAdmin, (req, res) => {
  const devices = db
    .prepare('SELECT id, name, device_token, created_at, last_seen_at FROM devices ORDER BY created_at DESC')
    .all();
  res.json({ devices });
});

app.post('/api/devices', requireAdmin, (req, res) => {
  const schema = z.object({ name: z.string().min(1).max(200).optional().default('Child device') });
  const { name } = schema.parse(req.body);

  const deviceId = id();
  const deviceToken = crypto.randomBytes(16).toString('hex');
  const deviceSecret = crypto.randomBytes(32).toString('hex');

  db.prepare('INSERT INTO devices (id, name, device_token, device_secret) VALUES (?, ?, ?, ?)').run(
    deviceId,
    name,
    deviceToken,
    deviceSecret
  );

  db.prepare(
    `
    INSERT INTO device_policies (id, device_id, enforce, set_hotspot_off, rotate_password, gap_ms)
    VALUES (?, ?, 1, 1, 1, 7200000)
    `
  ).run(id(), deviceId);

  res.status(201).json({ id: deviceId, name, deviceToken, deviceSecret });
});

// Create a short-lived pairing code for a device.
// The child app redeems it via POST /pair.
app.post('/api/devices/:deviceId/pairing-code', requireAdmin, (req, res, next) => {
  try {
    const { deviceId } = req.params;
    const schema = z.object({ ttlMinutes: z.number().int().min(1).max(60).optional().default(10) });
    const { ttlMinutes } = schema.parse(req.body || {});

    const device = db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
    if (!device) return res.status(404).json({ error: 'not_found' });

    // Best-effort cleanup of old codes for this device
    db.prepare('DELETE FROM pairing_codes WHERE device_id = ? AND (redeemed_at IS NOT NULL OR expires_at < ?)')
      .run(deviceId, Date.now());

    const code = randomPairingCode();
    const expiresAt = Date.now() + ttlMinutes * 60_000;
    db.prepare('INSERT INTO pairing_codes (code, device_id, expires_at) VALUES (?, ?, ?)').run(code, deviceId, expiresAt);

    res.status(201).json({ code, expiresAt, ttlMinutes });
  } catch (e) {
    next(e);
  }
});

app.patch('/api/devices/:deviceId/policy', requireAdmin, (req, res) => {
  const { deviceId } = req.params;
  const device = db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
  if (!device) return res.status(404).json({ error: 'not_found' });

  const schema = z.object({
    enforce: z.boolean().optional(),
    setHotspotOff: z.boolean().optional(),
    rotatePassword: z.boolean().optional(),
    quietStart: z.string().max(20).nullable().optional(),
    quietEnd: z.string().max(20).nullable().optional(),
    tz: z.string().max(60).nullable().optional(),
    gapMs: z.number().int().min(60_000).max(7 * 24 * 60 * 60 * 1000).optional(),
    gapMinutes: z.number().int().min(1).max(7 * 24 * 60).optional()
  });
  const patch = schema.parse(req.body);

  const existing = db.prepare('SELECT id FROM device_policies WHERE device_id = ?').get(deviceId);
  if (!existing) db.prepare('INSERT INTO device_policies (id, device_id) VALUES (?, ?)').run(id(), deviceId);

  const fields = [];
  const values = [];
  if (patch.enforce != null) {
    fields.push('enforce = ?');
    values.push(patch.enforce ? 1 : 0);
  }
  if (patch.setHotspotOff != null) {
    fields.push('set_hotspot_off = ?');
    values.push(patch.setHotspotOff ? 1 : 0);
  }
  if (patch.rotatePassword != null) {
    fields.push('rotate_password = ?');
    values.push(patch.rotatePassword ? 1 : 0);
  }
  if (patch.quietStart !== undefined) {
    fields.push('quiet_start = ?');
    values.push(patch.quietStart);
  }
  if (patch.quietEnd !== undefined) {
    fields.push('quiet_end = ?');
    values.push(patch.quietEnd);
  }
  if (patch.tz !== undefined) {
    fields.push('tz = ?');
    values.push(patch.tz);
  }

  const gapMs = patch.gapMs != null ? patch.gapMs : (patch.gapMinutes != null ? patch.gapMinutes * 60_000 : null);
  if (gapMs != null) {
    fields.push('gap_ms = ?');
    values.push(gapMs);
  }

  fields.push("updated_at = datetime('now')");

  db.prepare(`UPDATE device_policies SET ${fields.join(', ')} WHERE device_id = ?`).run(...values, deviceId);
  res.json({ ok: true });
});

app.get('/api/devices/:deviceId/events', requireAdmin, (req, res) => {
  const { deviceId } = req.params;
  const device = db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
  if (!device) return res.status(404).json({ error: 'not_found' });

  const events = db
    .prepare(
      `
      SELECT id, ts, trigger, shortcut_version, actions_attempted, result_ok, result_errors, created_at
      FROM device_events
      WHERE device_id = ?
      ORDER BY ts DESC
      LIMIT 200
      `
    )
    .all(deviceId)
    .map(e => ({
      ...e,
      actions_attempted: e.actions_attempted ? JSON.parse(e.actions_attempted) : [],
      result_errors: e.result_errors ? JSON.parse(e.result_errors) : []
    }));

  res.json({ events });
});

// Basic JSON error handler
app.use((err, req, res, next) => {
  const status = err?.status || 400;
  res.status(status).json({ error: 'bad_request', detail: String(err?.message || err) });
});

app.listen(PORT, HOST, () => {
  console.log(`[hotspot] listening on http://${HOST}:${PORT}`);
  console.log(`[hotspot] sqlite: ${DATABASE_PATH}`);
});
