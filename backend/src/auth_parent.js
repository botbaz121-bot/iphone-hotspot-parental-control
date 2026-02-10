import crypto from 'node:crypto';
import { jwtVerify, SignJWT, createRemoteJWKSet } from 'jose';

const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export function mustEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`missing ${name}`);
  return v;
}

export function optionalEnv(name, fallback = undefined) {
  const v = process.env[name];
  if (v == null || v === '') return fallback;
  return v;
}

export function splitCsv(v) {
  return String(v || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
}

export function hashSub(sub) {
  // Keep stable but non-reversible identifier for logging/debug.
  return crypto.createHash('sha256').update(String(sub)).digest('hex').slice(0, 12);
}

export async function verifyAppleIdentityToken({ identityToken, audience }) {
  // identityToken is a JWT signed by Apple.
  // We verify signature via Apple's JWKS, plus issuer + audience.
  const { payload } = await jwtVerify(identityToken, APPLE_JWKS, {
    issuer: 'https://appleid.apple.com',
    audience
  });
  return payload;
}

export async function mintSessionJwt({ parentId, appleSub, secret, ttlSeconds = 7 * 24 * 60 * 60 }) {
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT({ parentId })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(String(appleSub))
    .setIssuedAt(now)
    .setExpirationTime(now + ttlSeconds)
    .sign(Buffer.from(secret, 'utf8'));
}

export async function verifySessionJwt({ token, secret }) {
  const { payload } = await jwtVerify(token, Buffer.from(secret, 'utf8'), {
    algorithms: ['HS256']
  });
  return payload;
}
