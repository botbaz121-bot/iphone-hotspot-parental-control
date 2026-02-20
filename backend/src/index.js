import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import Database from 'better-sqlite3';
import { z } from 'zod';

import {
  optionalEnv,
  splitCsv,
  verifyAppleIdentityToken,
  mintSessionJwt,
  verifySessionJwt,
  hashSub
} from './auth_parent.js';

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
const SESSION_JWT_SECRET = env('SESSION_JWT_SECRET');
// Apple identity tokens will have an audience of your app's bundle id (iOS) or service id (web).
// Configure as comma-separated list: e.g. "com.bazapps.hotspotparent,com.bazapps.hotspotparent.dev".
const APPLE_AUDIENCES = splitCsv(env('APPLE_AUDIENCES', env('APPLE_SERVICE_ID', '')));
const APNS_TEAM_ID = env('APNS_TEAM_ID');
const APNS_KEY_ID = env('APNS_KEY_ID');
const APNS_PRIVATE_KEY = env('APNS_PRIVATE_KEY');
const APNS_PRIVATE_KEY_PATH = env('APNS_PRIVATE_KEY_PATH');
const APNS_TOPIC = env('APNS_TOPIC', 'com.bazapps.hotspotparent');
const APNS_ENV = String(env('APNS_ENV', 'sandbox')).toLowerCase(); // sandbox | production

const MAX_SKEW_MS = Number(env('MAX_SKEW_MS', String(5 * 60 * 1000)));
const LOG_REQUEST_BODIES = env('LOG_REQUEST_BODIES', '0') === '1';

fs.mkdirSync(path.dirname(DATABASE_PATH), { recursive: true });
const db = new Database(DATABASE_PATH);
db.pragma('journal_mode = WAL');

// Schema
// Notes:
// - MVP started with a single ADMIN_TOKEN. We now add parent auth (Sign in with Apple)
//   and a session JWT, and gradually move /api endpoints to parent-scoped access.
function tableHasColumn(table, column) {
  const cols = db.prepare(`PRAGMA table_info(${table})`).all();
  return cols.some(c => c.name === column);
}

db.exec(`
CREATE TABLE IF NOT EXISTS parents (
  id TEXT PRIMARY KEY,
  apple_sub TEXT NOT NULL UNIQUE,
  email TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  parent_id TEXT,
  name TEXT NOT NULL DEFAULT '',
  icon TEXT,
  device_token TEXT NOT NULL UNIQUE,
  device_secret TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_seen_at TEXT,
  FOREIGN KEY(parent_id) REFERENCES parents(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS device_policies (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE,
  activate_protection INTEGER NOT NULL DEFAULT 1,
  set_hotspot_off INTEGER NOT NULL DEFAULT 1,
  set_wifi_off INTEGER NOT NULL DEFAULT 0,
  set_mobile_data_off INTEGER NOT NULL DEFAULT 0,
  rotate_password INTEGER NOT NULL DEFAULT 1,
  quiet_start TEXT,
  quiet_end TEXT,
  quiet_days TEXT,
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

CREATE TABLE IF NOT EXISTS extra_time_requests (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  requested_minutes INTEGER NOT NULL,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  requested_at INTEGER NOT NULL,
  resolved_at INTEGER,
  resolved_by TEXT,
  granted_minutes INTEGER,
  starts_at INTEGER,
  ends_at INTEGER,
  FOREIGN KEY(device_id) REFERENCES devices(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS parent_push_tokens (
  token TEXT PRIMARY KEY,
  parent_id TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_used_at INTEGER,
  FOREIGN KEY(parent_id) REFERENCES parents(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_devices_created ON devices(created_at);
CREATE INDEX IF NOT EXISTS idx_device_events_device ON device_events(device_id);
CREATE INDEX IF NOT EXISTS idx_device_events_ts ON device_events(ts);
CREATE INDEX IF NOT EXISTS idx_pairing_codes_device ON pairing_codes(device_id);
CREATE INDEX IF NOT EXISTS idx_pairing_codes_expires ON pairing_codes(expires_at);
CREATE INDEX IF NOT EXISTS idx_extra_time_device ON extra_time_requests(device_id);
CREATE INDEX IF NOT EXISTS idx_extra_time_status ON extra_time_requests(status);
CREATE INDEX IF NOT EXISTS idx_extra_time_ends ON extra_time_requests(ends_at);
CREATE INDEX IF NOT EXISTS idx_parent_push_tokens_parent ON parent_push_tokens(parent_id);
`);

// Lightweight migration for existing DBs
if (db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='devices'").get()) {
  if (!tableHasColumn('devices', 'icon')) {
    db.exec("ALTER TABLE devices ADD COLUMN icon TEXT");
  }
}

if (db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='device_policies'").get()) {
  if (!tableHasColumn('device_policies', 'activate_protection')) {
    db.exec('ALTER TABLE device_policies ADD COLUMN activate_protection INTEGER NOT NULL DEFAULT 1');
  }
  if (!tableHasColumn('device_policies', 'gap_ms')) {
    db.exec('ALTER TABLE device_policies ADD COLUMN gap_ms INTEGER NOT NULL DEFAULT 7200000');
  }
  if (!tableHasColumn('device_policies', 'set_wifi_off')) {
    db.exec('ALTER TABLE device_policies ADD COLUMN set_wifi_off INTEGER NOT NULL DEFAULT 0');
  }
  if (!tableHasColumn('device_policies', 'set_mobile_data_off')) {
    db.exec('ALTER TABLE device_policies ADD COLUMN set_mobile_data_off INTEGER NOT NULL DEFAULT 0');
  }
  if (!tableHasColumn('device_policies', 'quiet_days')) {
    db.exec('ALTER TABLE device_policies ADD COLUMN quiet_days TEXT');
  }
}

if (db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='devices'").get()) {
  if (!tableHasColumn('devices', 'parent_id')) {
    db.exec('ALTER TABLE devices ADD COLUMN parent_id TEXT');
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

function randomPairingCode(len = 4) {
  // 4-char uppercase alnum (no 0/O/1/I) for easy manual entry.
  // Entropy: ~32^4 ≈ 1M combos; rely on short TTL + uniqueness enforcement.
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // avoid 0/O/1/I
  const bytes = crypto.randomBytes(len);
  let out = '';
  for (let i = 0; i < bytes.length; i++) out += alphabet[bytes[i] % alphabet.length];
  return out;
}

function normalizePairingCode(code) {
  return String(code || '').trim().toUpperCase();
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

async function requireParent(req, res, next) {
  try {
    const token = String(req.header('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
    if (!token) return res.status(401).json({ error: 'unauthorized' });
    if (!SESSION_JWT_SECRET) return res.status(500).json({ error: 'missing_session_secret' });

    const payload = await verifySessionJwt({ token, secret: SESSION_JWT_SECRET });
    const appleSub = String(payload.sub || '');
    const parentId = String(payload.parentId || '');
    if (!appleSub || !parentId) return res.status(401).json({ error: 'unauthorized' });

    const parent = db.prepare('SELECT id, apple_sub, email, created_at FROM parents WHERE id = ? AND apple_sub = ?').get(parentId, appleSub);
    if (!parent) return res.status(401).json({ error: 'unauthorized' });

    req.parent = parent;
    return next();
  } catch (e) {
    return res.status(401).json({ error: 'unauthorized' });
  }
}

function requireParentOrAdmin(req, res, next) {
  const token = String(req.header('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
  if (token && token === ADMIN_TOKEN) return next();
  return requireParent(req, res, next);
}

app.get('/healthz', (req, res) => res.json({ ok: true }));

// --- Sign in with Apple (Web) ---
const APPLE_TEAM_ID = env('APPLE_TEAM_ID');
const APPLE_KEY_ID = env('APPLE_KEY_ID');
const APPLE_SERVICE_ID = env('APPLE_SERVICE_ID');
const APPLE_REDIRECT_URI = env('APPLE_REDIRECT_URI', `https://hotspot.abomb.co.uk/auth/apple/callback`);
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

function apnsLoadPrivateKey() {
  if (APNS_PRIVATE_KEY) return APNS_PRIVATE_KEY;
  if (APNS_PRIVATE_KEY_PATH) return fs.readFileSync(APNS_PRIVATE_KEY_PATH, 'utf8');
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

function apnsMakeProviderToken() {
  if (!APNS_TEAM_ID || !APNS_KEY_ID) return null;
  const keyPem = apnsLoadPrivateKey();
  if (!keyPem) return null;

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'ES256', kid: APNS_KEY_ID, typ: 'JWT' };
  const payload = { iss: APNS_TEAM_ID, iat: now };
  const encodedHeader = base64url(JSON.stringify(header));
  const encodedPayload = base64url(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const sign = crypto.createSign('sha256');
  sign.update(signingInput);
  sign.end();
  const signature = sign.sign({ key: keyPem, dsaEncoding: 'ieee-p1363' });
  return `${signingInput}.${base64url(signature)}`;
}

async function apnsSendToToken(deviceToken, payload) {
  const providerToken = apnsMakeProviderToken();
  if (!providerToken) return { ok: false, skipped: 'missing_apns_config' };
  if (!APNS_TOPIC) return { ok: false, skipped: 'missing_apns_topic' };

  const host = APNS_ENV === 'production' ? 'api.push.apple.com' : 'api.sandbox.push.apple.com';
  const url = `https://${host}/3/device/${encodeURIComponent(deviceToken)}`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      authorization: `bearer ${providerToken}`,
      'apns-topic': APNS_TOPIC,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    return { ok: false, status: res.status, body: txt };
  }
  return { ok: true };
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

// State storage for Apple OAuth (server-side, avoids SameSite cookie issues with form_post).
db.exec(`
CREATE TABLE IF NOT EXISTS apple_oauth_states (
  state TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_apple_oauth_states_created ON apple_oauth_states(created_at);
`);

function appleStoreState(state) {
  db.prepare('INSERT INTO apple_oauth_states (state, created_at) VALUES (?, ?)').run(state, Date.now());
}

function appleConsumeState(state, maxAgeMs = 10 * 60 * 1000) {
  const row = db.prepare('SELECT state, created_at FROM apple_oauth_states WHERE state = ?').get(state);
  if (!row) return false;
  db.prepare('DELETE FROM apple_oauth_states WHERE state = ?').run(state);
  if (Date.now() - Number(row.created_at) > maxAgeMs) return false;
  return true;
}

// Start web auth: redirects user to Apple.
app.get('/auth/apple/start', (req, res) => {
  try {
    if (!APPLE_SERVICE_ID) return res.status(500).json({ error: 'missing APPLE_SERVICE_ID' });

    const state = randomState();
    appleStoreState(state);

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
    if (!state || !appleConsumeState(state)) {
      return res.status(400).json({ error: 'invalid state' });
    }

    const code = String(req.body?.code || req.query?.code || '').trim();
    if (!code) return res.status(400).json({ error: 'missing code' });

    const out = await appleTokenExchange(code);

    // Apple only sends name/email (in req.body.user) the first time per user+app.
    // Keep it visible for debugging now.
    let user = null;
    try {
      if (req.body?.user) user = typeof req.body.user === 'string' ? JSON.parse(req.body.user) : req.body.user;
    } catch {
      user = { raw: req.body?.user };
    }

    return res.json({ ok: true, apple: out, user });
  } catch (e) {
    return res.status(400).json({ ok: false, error: String(e?.message || e) });
  }
});

// --- Sign in with Apple (Native iOS) ---
// iOS sends us the identityToken (JWT signed by Apple). We verify it and mint our own session token.
app.post('/auth/apple/native', async (req, res) => {
  try {
    const schema = z.object({
      identityToken: z.string().min(20),
      email: z.string().email().optional(),
      fullName: z.string().max(200).optional()
    });
    const { identityToken, email } = schema.parse(req.body || {});

    if (!APPLE_AUDIENCES.length) return res.status(500).json({ error: 'missing_APPLE_AUDIENCES' });
    if (!SESSION_JWT_SECRET) return res.status(500).json({ error: 'missing_SESSION_JWT_SECRET' });

    // Try all allowed audiences.
    let payload = null;
    let lastErr = null;
    for (const aud of APPLE_AUDIENCES) {
      try {
        payload = await verifyAppleIdentityToken({ identityToken, audience: aud });
        break;
      } catch (e) {
        lastErr = e;
      }
    }
    if (!payload) return res.status(401).json({ error: 'invalid_identity_token' });

    const appleSub = String(payload.sub || '');
    if (!appleSub) return res.status(401).json({ error: 'invalid_identity_token' });

    // Upsert parent.
    let parent = db.prepare('SELECT id, apple_sub, email, created_at FROM parents WHERE apple_sub = ?').get(appleSub);
    if (!parent) {
      const parentId = id();
      db.prepare('INSERT INTO parents (id, apple_sub, email) VALUES (?, ?, ?)').run(parentId, appleSub, email || null);
      parent = db.prepare('SELECT id, apple_sub, email, created_at FROM parents WHERE id = ?').get(parentId);
    } else if (email && (!parent.email || String(parent.email).trim() === '')) {
      db.prepare('UPDATE parents SET email = ? WHERE id = ?').run(email, parent.id);
      parent = db.prepare('SELECT id, apple_sub, email, created_at FROM parents WHERE id = ?').get(parent.id);
    }

    const sessionToken = await mintSessionJwt({ parentId: parent.id, appleSub, secret: SESSION_JWT_SECRET });
    return res.json({ ok: true, parent: { id: parent.id, email: parent.email || null, appleSubHash: hashSub(appleSub) }, sessionToken });
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

const ADMIN_UI_PUBLIC = String(env('ADMIN_UI_PUBLIC', 'false')).toLowerCase() === 'true';

function parseBasicAuth(header) {
  const h = String(header || '');
  if (!h.toLowerCase().startsWith('basic ')) return null;
  try {
    const raw = Buffer.from(h.slice(6), 'base64').toString('utf8');
    const idx = raw.indexOf(':');
    if (idx === -1) return { user: raw, pass: '' };
    return { user: raw.slice(0, idx), pass: raw.slice(idx + 1) };
  } catch {
    return null;
  }
}

function isAdminAuth(req) {
  // Accept Bearer ADMIN_TOKEN (used by API calls)
  const bearer = String(req.header('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
  if (bearer && bearer === ADMIN_TOKEN) return true;

  // Also accept Basic auth for /admin page load.
  // Use username: admin, password: ADMIN_TOKEN.
  const basic = parseBasicAuth(req.header('Authorization'));
  if (basic && basic.user === 'admin' && basic.pass === ADMIN_TOKEN) return true;

  return false;
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
    req.path === '/extra-time/request' ||
    req.path.startsWith('/auth/apple')
  )
    return next();

  // /admin is a temporary debug UI. By default it's localhost-only.
  // If ADMIN_UI_PUBLIC=true (e.g. on Render), require Basic/Bearer admin auth.
  if (req.path === '/admin') {
    if (localHost) return next();
    if (!ADMIN_UI_PUBLIC) return res.status(404).type('text').send('not found');

    if (!isAdminAuth(req)) {
      res.set('WWW-Authenticate', 'Basic realm="Hotspot Admin"');
      return res.status(401).type('text').send('unauthorized');
    }

    return next();
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
        <th>Gap (min)</th>
        <th>Day</th>
        <th>Start</th>
        <th>End</th>
        <th>TZ</th>
        <th>Lock Apps</th>
        <th>Turn Hotspot off</th>
        <th>Turn Wi-Fi Off</th>
        <th>Turn Mobile Data Off</th>
        <th>Rotate password</th>
        <th>Last event</th>
        <th>Protection status</th>
        <th>Gap?</th>
        <th>Actions</th>
        <th>Pairing</th>
      </tr>
    </thead>
    <tbody></tbody>
  </table>

  <h3>Extra time requests</h3>
  <div class="muted">Pending requests from child devices. Approve grants temporary unlock time.</div>
  <table id="extraTbl">
    <thead>
      <tr>
        <th>Device</th>
        <th>Requested</th>
        <th>Reason</th>
        <th>Requested at</th>
        <th>Actions</th>
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
    const extraBody = $('extraTbl').querySelector('tbody');
    extraBody.innerHTML='';
    try{
      const dash = await api('/api/dashboard');
      const extra = await api('/api/extra-time/requests?status=pending');

      for(const d of dash.devices){
        const tr=document.createElement('tr');

        const gapMin = Math.round((d.gapMs||7200000) / 60000);
        const quietStart = d.quietHours && d.quietHours.start ? d.quietHours.start : '';
        const quietEnd = d.quietHours && d.quietHours.end ? d.quietHours.end : '';
        const tz = d.quietHours && d.quietHours.tz ? d.quietHours.tz : '';
        const quietDays = d.quietDays || null;

        const setHotspotOff = d.actions && d.actions.setHotspotOff ? true : false;
        const setWifiOff = d.actions && d.actions.setWifiOff ? true : false;
        const setMobileDataOff = d.actions && d.actions.setMobileDataOff ? true : false;
        const rotatePassword = d.actions && d.actions.rotatePassword ? true : false;
        const protectionStatus = d.statusMessage || '';

        tr.innerHTML =
          '<td>' + escapeHtml(d.name||'') + '</td>' +
          '<td><code>' + escapeHtml(d.device_token) + '</code></td>' +
          '<td><input class="gapMin" size="6" value="' + escapeHtml(String(gapMin)) + '" /></td>' +
          '<td>' +
            '<select class="daySel">' +
              '<option value="mon">M</option>' +
              '<option value="tue">T</option>' +
              '<option value="wed">W</option>' +
              '<option value="thu">T</option>' +
              '<option value="fri">F</option>' +
              '<option value="sat">S</option>' +
              '<option value="sun">S</option>' +
            '</select>' +
          '</td>' +
          '<td><input class="quietStart" type="time" value="' + escapeHtml(quietStart || '') + '" /></td>' +
          '<td><input class="quietEnd" type="time" value="' + escapeHtml(quietEnd || '') + '" /></td>' +
          '<td><input class="tz" size="18" placeholder="Europe/Paris" value="' + escapeHtml(tz) + '" /></td>' +
          '<td><label style="display:flex;gap:6px;align-items:center"><input type="checkbox" class="activateProtection" ' + (activateProtection ? 'checked' : '') + ' />On</label></td>' +
          '<td><label style="display:flex;gap:6px;align-items:center"><input type="checkbox" class="setHotspotOff" ' + (setHotspotOff ? 'checked' : '') + ' >Turn Hotspot off</label></td>' +
          '<td><label style="display:flex;gap:6px;align-items:center"><input type="checkbox" class="setWifiOff" ' + (setWifiOff ? 'checked' : '') + ' >Turn Wi-Fi Off</label></td>' +
          '<td><label style="display:flex;gap:6px;align-items:center"><input type="checkbox" class="setMobileDataOff" ' + (setMobileDataOff ? 'checked' : '') + ' >Turn Mobile Data Off</label></td>' +
          '<td><label style="display:flex;gap:6px;align-items:center"><input type="checkbox" class="rotatePassword" ' + (rotatePassword ? 'checked' : '') + ' />Rotate password</label></td>' +
          '<td>' + escapeHtml(d.last_event_at||'') + '</td>' +
          '<td>' + escapeHtml(protectionStatus) + '</td>' +
          '<td>' + (d.gap ? '<b>YES</b>' : 'no') + '</td>' +
          '<td>' +
            '<button class="saveRow">Save</button> ' +
            '<button class="eventsRow">Events</button>' +
          '</td>' +
          '<td>' +
            '<button class="pairRow">Pair code</button> ' +
            '<span class="pairOut" style="font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"></span>' +
          '</td>';

        // per-row quietDays model (preserved across day switching)
        let quietDaysModel = quietDays && typeof quietDays === 'object' ? JSON.parse(JSON.stringify(quietDays)) : {};

        function getSelDay(){
          return String(tr.querySelector('.daySel')?.value||'mon');
        }
        function applyDayToInputs(){
          const k=getSelDay();
          const w=quietDaysModel[k]||{};
          tr.querySelector('.quietStart').value = w.start || '';
          tr.querySelector('.quietEnd').value = w.end || '';
        }
        tr.querySelector('.daySel').value = (d.quietDay || 'mon');
        tr.querySelector('.daySel').onchange = ()=>applyDayToInputs();
        applyDayToInputs();

        tr.querySelector('.saveRow').onclick = async ()=>{
          const gapMinutes = Number(String(tr.querySelector('.gapMin').value||'').trim());
          const quietStartVal = String(tr.querySelector('.quietStart').value||'').trim();
          const quietEndVal = String(tr.querySelector('.quietEnd').value||'').trim();
          const tzVal = String(tr.querySelector('.tz').value||'').trim();

          const setHotspotOff = tr.querySelector('.setHotspotOff').checked;
          const setWifiOff = tr.querySelector('.setWifiOff').checked;
          const setMobileDataOff = tr.querySelector('.setMobileDataOff').checked;
          const rotatePassword = tr.querySelector('.rotatePassword').checked;
          const activateProtection = tr.querySelector('.activateProtection').checked;

          // write current day back into the model
          const k = getSelDay();
          if (quietStartVal && quietEndVal) quietDaysModel[k] = { start: quietStartVal, end: quietEndVal };
          else delete quietDaysModel[k];

          const patch = { activateProtection, setHotspotOff, setWifiOff, setMobileDataOff, rotatePassword };
          if (Number.isFinite(gapMinutes) && gapMinutes > 0) patch.gapMinutes = gapMinutes;
          patch.tz = tzVal ? tzVal : 'Europe/Paris';

          // If no days configured, store null (schedule off).
          patch.quietDays = Object.keys(quietDaysModel).length ? quietDaysModel : null;

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

      for (const r of (extra.requests || [])) {
        const tr = document.createElement('tr');
        const reason = String(r.reason || '').trim();
        tr.innerHTML =
          '<td>' + escapeHtml(r.deviceName || '') + '</td>' +
          '<td>' + escapeHtml(String(r.requestedMinutes || 0)) + ' min</td>' +
          '<td>' + (reason ? escapeHtml(reason) : '<span class="muted">none</span>') + '</td>' +
          '<td>' + escapeHtml(r.requestedAt ? new Date(r.requestedAt).toISOString() : '') + '</td>' +
          '<td>' +
            '<button class="approveReq">Approve</button> ' +
            '<button class="denyReq">Deny</button>' +
          '</td>';

        tr.querySelector('.approveReq').onclick = async ()=>{
          tr.style.opacity = '0.6';
          try{
            await api('/api/extra-time/requests/' + r.id + '/decision', {
              method:'POST',
              body: JSON.stringify({ decision: 'approve' })
            });
          } finally {
            tr.style.opacity = '1';
          }
          await refresh();
        };

        tr.querySelector('.denyReq').onclick = async ()=>{
          tr.style.opacity = '0.6';
          try{
            await api('/api/extra-time/requests/' + r.id + '/decision', {
              method:'POST',
              body: JSON.stringify({ decision: 'deny' })
            });
          } finally {
            tr.style.opacity = '1';
          }
          await refresh();
        };

        extraBody.appendChild(tr);
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

  // Log policy fetches as activity events (this may be the only reliable heartbeat signal).
  // Best-effort de-dupe: don't insert more than one policy_fetch per 60s per device.
  try {
    const now = Date.now();
    const last = db.prepare(
      `
      SELECT ts
      FROM device_events
      WHERE device_id = ? AND trigger = 'policy_fetch'
      ORDER BY ts DESC
      LIMIT 1
      `
    ).get(deviceId);

    if (!last || (now - Number(last.ts || 0)) > 60_000) {
      const shortcutVersion = String(req.header('X-Shortcut-Version') || req.header('X-SpotCheck-Shortcut-Version') || '').slice(0, 50) || null;
      db.prepare(
        `
        INSERT INTO device_events (id, device_id, ts, trigger, shortcut_version, actions_attempted, result_ok, result_errors)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `
      ).run(
        id(),
        deviceId,
        now,
        'policy_fetch',
        shortcutVersion,
        JSON.stringify(['fetch_policy']),
        1,
        JSON.stringify([])
      );
    }
  } catch (e) {
    // Don't block policy fetch if logging fails.
  }

  const pol = db
    .prepare(
      `
      SELECT activate_protection, set_hotspot_off, set_wifi_off, set_mobile_data_off, rotate_password, quiet_start, quiet_end, quiet_days, tz
      FROM device_policies
      WHERE device_id = ?
      `
    )
    .get(deviceId);

  const quietDays = parseQuietDaysJSON(pol?.quiet_days);

  const hasLegacySchedule = pol?.quiet_start != null && pol?.quiet_end != null;
  const legacySchedule = hasLegacySchedule
    ? { start: pol.quiet_start, end: pol.quiet_end, tz: pol?.tz || 'Europe/Paris' }
    : null;

  const tz = pol?.tz || 'Europe/Paris';
  const todayKey = weekdayKeyNow(tz);
  const todays = quietDays && quietDays[todayKey] ? quietDays[todayKey] : null;
  const hasDaySchedule = todays && todays.start && todays.end;

  const schedule = quietDays ? todays : legacySchedule;
  const hasSchedule = schedule && schedule.start && schedule.end;

  // Shortcut contract:
  // - The global "enforce" is computed by the backend.
  // - If ANY of Hotspot/Wi‑Fi/Mobile Data is configured OFF, then enforcement is potentially active.
  // - If a schedule is set and we're OUTSIDE the schedule window, enforce=false.
  const actions = {
    activateProtection: pol ? !!pol.activate_protection : true,
    setHotspotOff: pol ? !!pol.set_hotspot_off : true,
    setWifiOff: pol ? !!pol.set_wifi_off : false,
    setMobileDataOff: pol ? !!pol.set_mobile_data_off : false,
    rotatePassword: pol ? !!pol.rotate_password : true
  };

  const wantsEnforcement = !!(actions.setHotspotOff || actions.setWifiOff || actions.setMobileDataOff);

  const inScheduleWindow = hasSchedule
    ? isWithinQuietHours({ quietStart: schedule.start, quietEnd: schedule.end, tz })
    : true;

  const activeExtraTime = getActiveExtraTime(deviceId);
  const pendingExtraTime = getPendingExtraTime(deviceId);
  const enforce = wantsEnforcement && inScheduleWindow && !activeExtraTime;
  const isQuietHours = inScheduleWindow;
  const statusMessage = buildPolicyStatusMessage({ schedule, inScheduleWindow, activeExtraTime, pendingExtraTime, tz, actions });

  const out = {
    enforce,
    actions,
    activateProtection: actions.activateProtection,

    // New fields (per-day schedule)
    quietDays: quietDays,
    quietDay: todayKey,
    quietHours: schedule,
    // isQuietHours tells the Shortcut whether enforcement is active right now (schedule is evaluated server-side).
    isQuietHours,
    statusMessage,
    activeExtraTime: activeExtraTime
      ? {
          requestId: activeExtraTime.id,
          startsAt: Number(activeExtraTime.starts_at),
          endsAt: Number(activeExtraTime.ends_at),
          grantedMinutes: Number(activeExtraTime.granted_minutes || activeExtraTime.requested_minutes || 0)
        }
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

// Child device requests temporary extra time (e.g. pause enforcement for N minutes).
app.post('/extra-time/request', requireShortcutAuth, (req, res, next) => {
  try {
    const schema = z.object({
      minutes: z.number().int().min(1).max(240),
      reason: z.string().max(300).optional()
    });
    const body = schema.parse(req.body || {});

    const reqId = id();
    const now = Date.now();
    const reason = body.reason ? String(body.reason).trim() : null;

    db.prepare(
      `
      INSERT INTO extra_time_requests (id, device_id, requested_minutes, reason, status, requested_at)
      VALUES (?, ?, ?, ?, 'pending', ?)
      `
    ).run(reqId, req.shortcut.deviceId, body.minutes, reason, now);

    insertDeviceEvent({
      deviceId: req.shortcut.deviceId,
      trigger: 'extra_time_requested',
      actionsAttempted: ['request_extra_time']
    });

    // Best-effort push notification to parent devices.
    notifyParentExtraTimeRequest({
      deviceId: req.shortcut.deviceId,
      requestId: reqId,
      requestedMinutes: body.minutes,
      reason
    }).catch(() => {});

    return res.status(201).json({ ok: true, requestId: reqId, status: 'pending' });
  } catch (e) {
    next(e);
  }
});

// --- Public pairing (for the one-app flow) ---
// Parent creates a short-lived pairing code (admin-auth), then the child app redeems it here.
app.post('/pair', (req, res, next) => {
  try {
    const schema = z.object({
      code: z.string().length(4)
    });
    const { code } = schema.parse(req.body);

    const now = Date.now();
    const row = db
      .prepare(
        `
        SELECT code, device_id, expires_at, redeemed_at
        FROM pairing_codes
        WHERE code = ?
        `
      )
      .get(normalizePairingCode(code));

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

      // No device naming here; avoid prompting twice.
      // Naming happens on the parent side when the device is created, or later via policy edits.
    });
    tx();

    // Return device credentials to the child app ONCE.
    res.json({
      deviceId: device.id,
      name: device.name,
      deviceToken: device.device_token,
      deviceSecret: device.device_secret
    });
  } catch (e) {
    next(e);
  }
});

// --- Parent API (iOS app) ---
// These are the endpoints the parent iOS app will call once signed in.

// Parent dashboard summary (scoped to parent).
app.get('/api/me', requireParent, (req, res) => {
  return res.json({ ok: true, parent: { id: req.parent.id, email: req.parent.email || null, created_at: req.parent.created_at } });
});

app.post('/api/push/register', requireParent, (req, res, next) => {
  try {
    const schema = z.object({
      deviceToken: z.string().min(16).max(512),
      platform: z.enum(['ios']).optional().default('ios')
    });
    const body = schema.parse(req.body || {});
    const token = String(body.deviceToken).trim();
    if (!token) return res.status(400).json({ error: 'invalid_token' });

    db.prepare(
      `
      INSERT INTO parent_push_tokens (token, parent_id, platform, updated_at)
      VALUES (?, ?, ?, datetime('now'))
      ON CONFLICT(token) DO UPDATE SET
        parent_id = excluded.parent_id,
        platform = excluded.platform,
        updated_at = datetime('now')
      `
    ).run(token, req.parent.id, body.platform);

    return res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

app.get('/api/dashboard', requireParentOrAdmin, (req, res) => {
  const parentId = req.parent?.id || null;
  const where = parentId ? 'WHERE d.parent_id = ?' : '';
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
        p.set_hotspot_off AS set_hotspot_off,
        p.set_wifi_off AS set_wifi_off,
        p.set_mobile_data_off AS set_mobile_data_off,
        p.rotate_password AS rotate_password,
        p.activate_protection AS activate_protection,
        p.quiet_start AS quiet_start,
        p.quiet_end AS quiet_end,
        p.quiet_days AS quiet_days,
        p.tz AS tz,
        p.gap_ms AS gap_ms
      FROM devices d
      LEFT JOIN device_events e ON e.device_id = d.id
      LEFT JOIN device_policies p ON p.device_id = d.id
      ${where}
      GROUP BY d.id
      ORDER BY d.created_at DESC
      `
    )
    .all(...(parentId ? [parentId] : []));

  const now = Date.now();
  const devices = rows.map(r => {
    const lastEventTs = r.last_event_ts != null ? Number(r.last_event_ts) : null;
    const gapMs = r.gap_ms != null ? Number(r.gap_ms) : 7200000;

    const setHotspotOff = r.set_hotspot_off == null ? true : !!r.set_hotspot_off;
    const setWifiOff = r.set_wifi_off == null ? false : !!r.set_wifi_off;
    const setMobileDataOff = r.set_mobile_data_off == null ? false : !!r.set_mobile_data_off;
    const rotatePassword = r.rotate_password == null ? true : !!r.rotate_password;
    const activateProtection = r.activate_protection == null ? true : !!r.activate_protection;

    const actions = { activateProtection, setHotspotOff, setWifiOff, setMobileDataOff, rotatePassword };
    const wantsEnforcement = !!(actions.setHotspotOff || actions.setWifiOff || actions.setMobileDataOff);

    const quietDays = parseQuietDaysJSON(r.quiet_days);
    const tz = r.tz || 'Europe/Paris';

    const hasLegacySchedule = r.quiet_start != null && r.quiet_end != null;

    const todayKey = weekdayKeyNow(tz);
    const todays = quietDays && quietDays[todayKey] ? quietDays[todayKey] : null;
    const hasDaySchedule = todays && todays.start && todays.end;

    const schedule = quietDays
      ? (hasDaySchedule ? { start: todays.start, end: todays.end, tz } : null)
      : (hasLegacySchedule ? { start: r.quiet_start, end: r.quiet_end, tz } : null);

    const hasSchedule = schedule && schedule.start && schedule.end;
    const inScheduleWindow = hasSchedule
      ? isWithinQuietHours({ quietStart: schedule.start, quietEnd: schedule.end, tz })
      : true;

    const activeExtraTime = getActiveExtraTime(r.id, now);
    const pendingExtraTime = getPendingExtraTime(r.id);
    const enforce = wantsEnforcement && inScheduleWindow && !activeExtraTime;
    const inQuiet = inScheduleWindow;
    const statusMessage = buildPolicyStatusMessage({
      schedule,
      inScheduleWindow,
      activeExtraTime,
      pendingExtraTime,
      tz,
      actions
    });

    // New semantics: "inQuietHours" means within the enforcement schedule.
    const shouldBeRunning = enforce;

    const gap = shouldBeRunning ? (lastEventTs == null ? true : now - lastEventTs > gapMs) : false;

    return {
      id: r.id,
      name: r.name,
      device_token: r.device_token,
      created_at: r.created_at,
      last_seen_at: r.last_seen_at,
      last_event_ts: lastEventTs,
      last_event_at: lastEventTs ? new Date(lastEventTs).toISOString() : null,
      enforce,
      actions,
      quietDays: quietDays,
      quietDay: todayKey,
      quietHours: schedule,
      inQuietHours: inQuiet,
      statusMessage,
      activeExtraTime: activeExtraTime
        ? {
            requestId: activeExtraTime.id,
            startsAt: Number(activeExtraTime.starts_at),
            endsAt: Number(activeExtraTime.ends_at),
            grantedMinutes: Number(activeExtraTime.granted_minutes || activeExtraTime.requested_minutes || 0)
          }
        : null,
      shouldBeRunning,
      gapMs,
      gap
    };
  });

  res.json({ devices });
});

app.get('/api/devices', requireParentOrAdmin, (req, res) => {
  const parentId = req.parent?.id || null;
  const devices = parentId
    ? db
        .prepare('SELECT id, name, device_token, created_at, last_seen_at FROM devices WHERE parent_id = ? ORDER BY created_at DESC')
        .all(parentId)
    : db.prepare('SELECT id, name, device_token, created_at, last_seen_at FROM devices ORDER BY created_at DESC').all();
  res.json({ devices });
});

app.post('/api/devices', requireParentOrAdmin, (req, res) => {
  const schema = z.object({ name: z.string().trim().min(1).max(200) });
  const { name } = schema.parse(req.body || {});

  if (!req.parent && String(req.header('Authorization') || '').replace(/^Bearer\s+/i, '').trim() !== ADMIN_TOKEN) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const deviceId = id();
  const deviceToken = crypto.randomBytes(16).toString('hex');
  const deviceSecret = crypto.randomBytes(32).toString('hex');

  db.prepare('INSERT INTO devices (id, parent_id, name, device_token, device_secret) VALUES (?, ?, ?, ?, ?)').run(
    deviceId,
    req.parent?.id || null,
    name,
    deviceToken,
    deviceSecret
  );

  db.prepare(
    `
    INSERT INTO device_policies (id, device_id, activate_protection, set_hotspot_off, set_wifi_off, set_mobile_data_off, rotate_password, gap_ms)
    VALUES (?, ?, 1, 1, 0, 0, 1, 7200000)
    `
  ).run(id(), deviceId);

  // NOTE: deviceSecret should not be shown in the parent app UI; it is for the child/Shortcut.
  res.status(201).json({ id: deviceId, name, deviceToken, deviceSecret });
});

// Create a short-lived pairing code for a device.
app.patch('/api/devices/:deviceId', requireParentOrAdmin, (req, res, next) => {
  try {
    const { deviceId } = req.params;

    const device = req.parent
      ? db.prepare('SELECT id FROM devices WHERE id = ? AND parent_id = ?').get(deviceId, req.parent.id)
      : db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
    if (!device) return res.status(404).json({ error: 'not_found' });

    const schema = z.object({
      name: z.string().min(1).max(200).optional(),
      icon: z.string().min(1).max(60).nullable().optional()
    });
    const patch = schema.parse(req.body || {});

    const fields = [];
    const values = [];
    if (patch.name != null) {
      fields.push('name = ?');
      values.push(patch.name);
    }
    if (patch.icon !== undefined) {
      fields.push('icon = ?');
      values.push(patch.icon);
    }

    if (!fields.length) return res.status(400).json({ error: 'no_fields' });

    values.push(deviceId);
    db.prepare(`UPDATE devices SET ${fields.join(', ')} WHERE id = ?`).run(...values);

    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

app.delete('/api/devices/:deviceId', requireParentOrAdmin, (req, res, next) => {
  try {
    const { deviceId } = req.params;

    const device = req.parent
      ? db.prepare('SELECT id FROM devices WHERE id = ? AND parent_id = ?').get(deviceId, req.parent.id)
      : db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
    if (!device) return res.status(404).json({ error: 'not_found' });

    db.prepare('DELETE FROM devices WHERE id = ?').run(deviceId);
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

app.post('/api/devices/:deviceId/pairing-code', requireParentOrAdmin, (req, res, next) => {
  try {
    const { deviceId } = req.params;
    const schema = z.object({ ttlMinutes: z.number().int().min(1).max(60).optional().default(10) });
    const { ttlMinutes } = schema.parse(req.body || {});

    const device = req.parent
      ? db.prepare('SELECT id FROM devices WHERE id = ? AND parent_id = ?').get(deviceId, req.parent.id)
      : db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);

    if (!device) return res.status(404).json({ error: 'not_found' });

    db.prepare('DELETE FROM pairing_codes WHERE device_id = ? AND (redeemed_at IS NOT NULL OR expires_at < ?)').run(
      deviceId,
      Date.now()
    );

    const expiresAt = Date.now() + ttlMinutes * 60_000;

    // Ensure uniqueness (collision is rare but possible with 4 chars).
    let code = null;
    for (let i = 0; i < 8; i++) {
      const candidate = randomPairingCode(4);
      try {
        db.prepare('INSERT INTO pairing_codes (code, device_id, expires_at) VALUES (?, ?, ?)').run(candidate, deviceId, expiresAt);
        code = candidate;
        break;
      } catch (e) {
        // SQLite constraint -> try again.
        if (String(e?.message || '').toLowerCase().includes('constraint')) continue;
        throw e;
      }
    }
    if (!code) return res.status(503).json({ error: 'pairing_code_generation_failed' });

    res.status(201).json({ code, expiresAt, ttlMinutes });
  } catch (e) {
    next(e);
  }
});

app.patch('/api/devices/:deviceId/policy', requireParentOrAdmin, (req, res) => {
  const { deviceId } = req.params;
  const device = req.parent
    ? db.prepare('SELECT id FROM devices WHERE id = ? AND parent_id = ?').get(deviceId, req.parent.id)
    : db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
  if (!device) return res.status(404).json({ error: 'not_found' });

  const schema = z.object({
    activateProtection: z.boolean().optional(),
    setHotspotOff: z.boolean().optional(),
    setWifiOff: z.boolean().optional(),
    setMobileDataOff: z.boolean().optional(),
    rotatePassword: z.boolean().optional(),
    quietStart: z.string().max(20).nullable().optional(),
    quietEnd: z.string().max(20).nullable().optional(),
    quietDays: z.record(z.string(), z.object({ start: z.string().max(20), end: z.string().max(20) })).nullable().optional(),
    tz: z.string().max(60).nullable().optional(),
    gapMs: z.number().int().min(60_000).max(7 * 24 * 60 * 60 * 1000).optional(),
    gapMinutes: z.number().int().min(1).max(7 * 24 * 60).optional()
  });
  const patch = schema.parse(req.body);

  const existing = db.prepare('SELECT id FROM device_policies WHERE device_id = ?').get(deviceId);
  if (!existing) db.prepare('INSERT INTO device_policies (id, device_id) VALUES (?, ?)').run(id(), deviceId);

  const fields = [];
  const values = [];
  if (patch.activateProtection != null) {
    fields.push('activate_protection = ?');
    values.push(patch.activateProtection ? 1 : 0);
  }
  if (patch.setHotspotOff != null) {
    fields.push('set_hotspot_off = ?');
    values.push(patch.setHotspotOff ? 1 : 0);
  }
  if (patch.setWifiOff != null) {
    fields.push('set_wifi_off = ?');
    values.push(patch.setWifiOff ? 1 : 0);
  }
  if (patch.setMobileDataOff != null) {
    fields.push('set_mobile_data_off = ?');
    values.push(patch.setMobileDataOff ? 1 : 0);
  }
  if (patch.rotatePassword != null) {
    fields.push('rotate_password = ?');
    values.push(patch.rotatePassword ? 1 : 0);
  }
  if (patch.quietDays !== undefined) {
    fields.push('quiet_days = ?');
    values.push(patch.quietDays ? JSON.stringify(patch.quietDays) : null);
    // If quietDays is set, clear legacy fields to avoid confusion.
    if (patch.quietDays != null) {
      fields.push('quiet_start = NULL');
      fields.push('quiet_end = NULL');
    }
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

  const gapMs = patch.gapMs != null ? patch.gapMs : patch.gapMinutes != null ? patch.gapMinutes * 60_000 : null;
  if (gapMs != null) {
    fields.push('gap_ms = ?');
    values.push(gapMs);
  }

  fields.push("updated_at = datetime('now')");

  if (!fields.length) return res.json({ ok: true });

  db.prepare(`UPDATE device_policies SET ${fields.join(', ')} WHERE device_id = ?`).run(...values, deviceId);
  res.json({ ok: true });
});

app.post('/api/devices/:deviceId/extra-time/grant', requireParentOrAdmin, (req, res, next) => {
  try {
    const { deviceId } = req.params;
    const device = req.parent
      ? db.prepare('SELECT id FROM devices WHERE id = ? AND parent_id = ?').get(deviceId, req.parent.id)
      : db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
    if (!device) return res.status(404).json({ error: 'not_found' });

    const schema = z.object({
      minutes: z.number().int().min(0).max(240),
      reason: z.string().max(300).optional()
    });
    const body = schema.parse(req.body || {});
    const now = Date.now();
    const minutes = Number(body.minutes);
    const endsAt = now + minutes * 60_000;

    // Parent latest decision should override any currently active window.
    db.prepare(
      `
      UPDATE extra_time_requests
      SET ends_at = ?
      WHERE device_id = ?
        AND status = 'approved'
        AND starts_at IS NOT NULL
        AND ends_at IS NOT NULL
        AND starts_at <= ?
        AND ends_at > ?
      `
    ).run(now, deviceId, now, now);

    const requestId = id();
    db.prepare(
      `
      INSERT INTO extra_time_requests (
        id, device_id, requested_minutes, reason, status, requested_at,
        resolved_at, resolved_by, granted_minutes, starts_at, ends_at
      )
      VALUES (?, ?, ?, ?, 'approved', ?, ?, ?, ?, ?, ?)
      `
    ).run(
      requestId,
      deviceId,
      minutes,
      body.reason ? String(body.reason).trim() : 'manual_grant',
      now,
      now,
      req.parent ? req.parent.id : 'admin',
      minutes,
      now,
      endsAt
    );

    insertDeviceEvent({
      deviceId,
      trigger: 'extra_time_applied',
      actionsAttempted: ['grant_extra_time']
    });

    return res.json({ ok: true, requestId, startsAt: now, endsAt, grantedMinutes: minutes });
  } catch (e) {
    next(e);
  }
});

app.get('/api/devices/:deviceId/events', requireParentOrAdmin, (req, res) => {
  const { deviceId } = req.params;
  const device = req.parent
    ? db.prepare('SELECT id FROM devices WHERE id = ? AND parent_id = ?').get(deviceId, req.parent.id)
    : db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
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

app.get('/api/extra-time/requests', requireParentOrAdmin, (req, res) => {
  const schema = z.object({
    status: z.enum(['pending', 'approved', 'denied', 'all']).optional(),
    deviceId: z.string().uuid().optional()
  });
  const q = schema.parse(req.query || {});

  const where = [];
  const values = [];

  if (req.parent) {
    where.push('d.parent_id = ?');
    values.push(req.parent.id);
  }
  if (q.deviceId) {
    where.push('r.device_id = ?');
    values.push(q.deviceId);
  }
  if (q.status && q.status !== 'all') {
    where.push('r.status = ?');
    values.push(q.status);
  }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const requests = db
    .prepare(
      `
      SELECT
        r.id,
        r.device_id,
        d.name AS device_name,
        r.requested_minutes,
        r.reason,
        r.status,
        r.requested_at,
        r.resolved_at,
        r.resolved_by,
        r.granted_minutes,
        r.starts_at,
        r.ends_at
      FROM extra_time_requests r
      JOIN devices d ON d.id = r.device_id
      ${whereSql}
      ORDER BY r.requested_at DESC
      LIMIT 500
      `
    )
    .all(...values)
    .map(r => ({
      id: r.id,
      deviceId: r.device_id,
      deviceName: r.device_name,
      requestedMinutes: Number(r.requested_minutes),
      reason: r.reason || null,
      status: r.status,
      requestedAt: Number(r.requested_at),
      resolvedAt: r.resolved_at != null ? Number(r.resolved_at) : null,
      resolvedBy: r.resolved_by || null,
      grantedMinutes: r.granted_minutes != null ? Number(r.granted_minutes) : null,
      startsAt: r.starts_at != null ? Number(r.starts_at) : null,
      endsAt: r.ends_at != null ? Number(r.ends_at) : null
    }));

  res.json({ requests });
});

app.post('/api/extra-time/requests/:requestId/decision', requireParentOrAdmin, (req, res, next) => {
  try {
    const schema = z.object({
      decision: z.enum(['approve', 'deny']),
      grantedMinutes: z.number().int().min(0).max(240).optional()
    });
    const { decision, grantedMinutes } = schema.parse(req.body || {});

    const row = req.parent
      ? db
          .prepare(
            `
            SELECT r.id, r.device_id, r.requested_minutes, r.status
            FROM extra_time_requests r
            JOIN devices d ON d.id = r.device_id
            WHERE r.id = ? AND d.parent_id = ?
            `
          )
          .get(req.params.requestId, req.parent.id)
      : db.prepare('SELECT id, device_id, requested_minutes, status FROM extra_time_requests WHERE id = ?').get(req.params.requestId);

    if (!row) return res.status(404).json({ error: 'not_found' });
    if (String(row.status) !== 'pending') return res.status(409).json({ error: 'already_resolved' });

    const now = Date.now();

    if (decision === 'deny') {
      db.prepare(
        `
        UPDATE extra_time_requests
        SET status = 'denied', resolved_at = ?, resolved_by = ?, granted_minutes = NULL, starts_at = NULL, ends_at = NULL
        WHERE id = ?
        `
      ).run(now, req.parent ? req.parent.id : 'admin', row.id);
      insertDeviceEvent({
        deviceId: row.device_id,
        trigger: 'extra_time_denied',
        actionsAttempted: ['deny_extra_time']
      });
      return res.json({ ok: true, status: 'denied' });
    }

    const minutes = grantedMinutes != null ? grantedMinutes : Number(row.requested_minutes);
    const endsAt = now + minutes * 60_000;
    // Parent latest decision should override any currently active window.
    db.prepare(
      `
      UPDATE extra_time_requests
      SET ends_at = ?
      WHERE device_id = ?
        AND status = 'approved'
        AND starts_at IS NOT NULL
        AND ends_at IS NOT NULL
        AND starts_at <= ?
        AND ends_at > ?
      `
    ).run(now, row.device_id, now, now);

    db.prepare(
      `
      UPDATE extra_time_requests
      SET status = 'approved', resolved_at = ?, resolved_by = ?, granted_minutes = ?, starts_at = ?, ends_at = ?
      WHERE id = ?
      `
    ).run(now, req.parent ? req.parent.id : 'admin', minutes, now, endsAt, row.id);

    insertDeviceEvent({
      deviceId: row.device_id,
      trigger: 'extra_time_applied',
      actionsAttempted: ['approve_extra_time']
    });

    return res.json({ ok: true, status: 'approved', startsAt: now, endsAt, grantedMinutes: minutes });
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

function withDefaultQuiet(quietStart, quietEnd) {
  // Shortcut-friendly default: never return nulls.
  // 12:00 → 12:00 is treated as "disabled" (not 24h quiet).
  const qs = quietStart == null || String(quietStart).trim() === '' ? '12:00' : String(quietStart);
  const qe = quietEnd == null || String(quietEnd).trim() === '' ? '12:00' : String(quietEnd);
  return { qs, qe };
}

function isWithinQuietHours({ quietStart, quietEnd, tz }) {
  const { qs, qe } = withDefaultQuiet(quietStart, quietEnd);

  const s = parseHHMM(qs);
  const e = parseHHMM(qe);
  if (s == null || e == null) return false;

  // Treat equal times as "quiet disabled".
  if (s === e) return false;

  const nowMin = getMinutesInTzNow(tz);

  // Range can cross midnight.
  if (s < e) return nowMin >= s && nowMin < e;
  return nowMin >= s || nowMin < e;
}

function weekdayKeyNow(tz) {
  const wd = new Intl.DateTimeFormat('en-US', { timeZone: tz || 'Europe/Paris', weekday: 'short' }).format(new Date());
  const map = { Mon: 'mon', Tue: 'tue', Wed: 'wed', Thu: 'thu', Fri: 'fri', Sat: 'sat', Sun: 'sun' };
  return map[wd] || 'mon';
}

function parseQuietDaysJSON(raw) {
  if (raw == null) return null;
  try {
    const s = String(raw).trim();
    if (!s) return null;
    const obj = JSON.parse(s);
    if (!obj || typeof obj !== 'object') return null;
    return obj;
  } catch {
    return null;
  }
}

function getActiveExtraTime(deviceId, nowMs = Date.now()) {
  return db
    .prepare(
      `
      SELECT id, requested_minutes, granted_minutes, starts_at, ends_at
      FROM extra_time_requests
      WHERE device_id = ?
        AND status = 'approved'
        AND starts_at IS NOT NULL
        AND ends_at IS NOT NULL
        AND starts_at <= ?
        AND ends_at > ?
      ORDER BY starts_at DESC, ends_at DESC
      LIMIT 1
      `
    )
    .get(deviceId, nowMs, nowMs);
}

function getPendingExtraTime(deviceId) {
  return db
    .prepare(
      `
      SELECT id, requested_minutes, requested_at
      FROM extra_time_requests
      WHERE device_id = ?
        AND status = 'pending'
      ORDER BY requested_at DESC
      LIMIT 1
      `
    )
    .get(deviceId);
}

function formatTimeInTz(date, tz) {
  try {
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: tz || 'Europe/Paris',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).formatToParts(date);
    const hh = parts.find(p => p.type === 'hour')?.value;
    const mm = parts.find(p => p.type === 'minute')?.value;
    if (hh && mm) return `${hh}:${mm}`;
  } catch {
    // fall through
  }
  const h = String(date.getHours()).padStart(2, '0');
  const m = String(date.getMinutes()).padStart(2, '0');
  return `${h}:${m}`;
}

function formatProtectedActions({ activateProtection, setHotspotOff, setWifiOff, setMobileDataOff }) {
  const labels = [];
  if (activateProtection) labels.push('Apps');
  if (setHotspotOff) labels.push('Hotspot');
  if (setWifiOff) labels.push('Wi-Fi');
  if (setMobileDataOff) labels.push('Mobile Data');

  if (!labels.length) return 'No protections are configured.';
  if (labels.length === 1) return `${labels[0]} is protected.`;
  if (labels.length === 2) return `${labels[0]} and ${labels[1]} are protected.`;
  return `${labels.slice(0, -1).join(', ')}, and ${labels[labels.length - 1]} are protected.`;
}

function scheduleStartSuffix({ start, end, tz }) {
  const s = parseHHMM(start);
  const e = parseHHMM(end);
  if (s == null || e == null) return `at ${start}`;
  const nowMin = getMinutesInTzNow(tz);
  if (s < e && nowMin >= e) return `at ${start} tomorrow`;
  return `at ${start}`;
}

function buildPolicyStatusMessage({ schedule, inScheduleWindow, activeExtraTime, pendingExtraTime, tz, actions }) {
  const details = formatProtectedActions(actions);
  const hasSchedule = !!(schedule && schedule.start && schedule.end);

  if (activeExtraTime && activeExtraTime.ends_at) {
    const resume = formatTimeInTz(new Date(Number(activeExtraTime.ends_at)), tz);
    return `Protection is currently off for approved extra time and scheduled to resume at ${resume}. ${details}`;
  }

  if (pendingExtraTime) {
    if (!hasSchedule) return `Protection is currently on. Extra time request is pending parent approval. ${details}`;
    if (inScheduleWindow) return `Protection is currently on and scheduled to end at ${schedule.end}. Extra time request is pending parent approval. ${details}`;
    return `Protection is currently off and scheduled to start ${scheduleStartSuffix({ start: schedule.start, end: schedule.end, tz })}. Extra time request is pending parent approval. ${details}`;
  }

  if (!hasSchedule) return `Protection is currently on. ${details}`;
  if (inScheduleWindow) return `Protection is currently on and scheduled to end at ${schedule.end}. ${details}`;
  return `Protection is currently off and scheduled to start ${scheduleStartSuffix({ start: schedule.start, end: schedule.end, tz })}. ${details}`;
}

function insertDeviceEvent({
  deviceId,
  trigger,
  shortcutVersion = null,
  actionsAttempted = [],
  resultOk = true,
  resultErrors = [],
  ts = Date.now()
}) {
  db.prepare(
    `
    INSERT INTO device_events (id, device_id, ts, trigger, shortcut_version, actions_attempted, result_ok, result_errors)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `
  ).run(
    id(),
    deviceId,
    ts,
    trigger,
    shortcutVersion,
    JSON.stringify(actionsAttempted || []),
    resultOk ? 1 : 0,
    JSON.stringify(resultErrors || [])
  );
}

async function notifyParentExtraTimeRequest({ deviceId, requestId, requestedMinutes, reason }) {
  const device = db.prepare('SELECT id, parent_id, name FROM devices WHERE id = ?').get(deviceId);
  if (!device || !device.parent_id) return { ok: false, skipped: 'no_parent' };

  const tokens = db
    .prepare('SELECT token FROM parent_push_tokens WHERE parent_id = ? ORDER BY updated_at DESC')
    .all(device.parent_id);
  if (!tokens.length) return { ok: false, skipped: 'no_tokens' };

  const title = 'Extra time requested';
  const body = `${device.name} requested ${requestedMinutes} more min`;
  const payload = {
    aps: { alert: { title, body }, sound: 'default' },
    type: 'extra_time_request',
    deviceId,
    requestId,
    requestedMinutes: Number(requestedMinutes || 0),
    reason: reason || ''
  };

  let delivered = 0;
  for (const t of tokens) {
    const token = String(t.token || '').trim();
    if (!token) continue;
    try {
      const out = await apnsSendToToken(token, payload);
      if (out.ok) {
        delivered += 1;
        db.prepare("UPDATE parent_push_tokens SET last_used_at = ?, updated_at = datetime('now') WHERE token = ?").run(Date.now(), token);
      } else if (out.status === 400 || out.status === 410) {
        // Expired/invalid token, prune it.
        db.prepare('DELETE FROM parent_push_tokens WHERE token = ?').run(token);
      }
    } catch {
      // keep trying remaining tokens
    }
  }

  return { ok: delivered > 0, delivered };
}

// Basic JSON error handler
app.use((err, req, res, next) => {
  const status = err?.status || 400;
  res.status(status).json({ error: 'bad_request', detail: String(err?.message || err) });
});

app.listen(PORT, HOST, () => {
  console.log(`[hotspot] listening on http://${HOST}:${PORT}`);
  console.log(`[hotspot] sqlite: ${DATABASE_PATH}`);
});
