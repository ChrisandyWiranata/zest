import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Session token buatan server (bukan Google idToken): dipakai web agar sesi
 * bertahan 1 hari penuh tanpa bergantung pada prompt One Tap Google tiap reload.
 *
 * Format: `zest_session.<header>.<payload>.<sig>` — struktur JWT (alg HS256)
 * supaya helper klien (`isIdTokenFresh`) tetap bisa membaca `exp`-nya.
 * Sekali terbit TIDAK diperpanjang oleh reload: masa berlaku menempel ke
 * terakhir kalinya klien memperoleh credential Google asli.
 */
export const SESSION_PREFIX = 'zest_session.';

const HEADER_B64 = base64url(Buffer.from('{"alg":"HS256","typ":"ZST"}'));
const MAX_TOKEN_LENGTH = 4096;
const CLOCK_SKEW_SECONDS = 30;

const BOUNDS = { uid: 128, email: 320, name: 256, picture: 512 };

function base64url(buf) {
  return buf.toString('base64').replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function base64urlJson(value) {
  return base64url(Buffer.from(JSON.stringify(value)));
}

/// Secret dibaca lazily supaya test bisa mengatur env per-case.
function sessionSecret() {
  const secret = process.env.SESSION_SECRET?.trim() ?? '';
  return secret.length >= 16 ? secret : null;
}

/// TTL dalam detik; default 24 jam, `SESSION_TTL_HOURS` bisa mengubah (desimal
/// didukung untuk uji cepat), minimal 60 detik.
export function sessionTtlSeconds() {
  const hours = Number.parseFloat(process.env.SESSION_TTL_HOURS ?? '24');
  const seconds = Number.isFinite(hours) && hours > 0 ? hours * 3600 : 86400;
  return Math.max(60, Math.round(seconds));
}

function clip(value, max) {
  return typeof value === 'string' ? value.slice(0, max) : '';
}

/**
 * Terbitkan session token untuk user terverifikasi.
 * Mengembalikan `null` bila `SESSION_SECRET` tidak diset (fitur nonaktif).
 */
export function createSessionToken(user) {
  const secret = sessionSecret();
  if (!secret || typeof user?.uid !== 'string' || !user.uid) return null;

  const now = Math.floor(Date.now() / 1000);
  const payload = base64urlJson({
    uid: clip(user.uid, BOUNDS.uid),
    email: clip(user.email, BOUNDS.email),
    name: clip(user.displayName, BOUNDS.name),
    picture: clip(user.photoUrl, BOUNDS.picture),
    iat: now,
    exp: now + sessionTtlSeconds(),
  });
  const signingInput = `${HEADER_B64}.${payload}`;
  const signature = base64url(
    createHmac('sha256', secret).update(signingInput).digest(),
  );
  return `${SESSION_PREFIX}${signingInput}.${signature}`;
}

/**
 * Verifikasi session token → klaim (`uid`, `email`, `displayName`,
 * `photoUrl`) atau `null` bila tidak sah (prefix salah, tanda tangan salah,
 * kedaluwarsa, payload aneh, atau `SESSION_SECRET` tidak diset).
 */
export function verifySessionToken(token) {
  const secret = sessionSecret();
  if (!secret || typeof token !== 'string') return null;
  if (token.length > MAX_TOKEN_LENGTH) return null;
  if (!token.startsWith(SESSION_PREFIX)) return null;

  const parts = token.slice(SESSION_PREFIX.length).split('.');
  if (parts.length !== 3) return null;
  const [header, payload, signature] = parts;
  if (header !== HEADER_B64) return null;

  const expected = createHmac('sha256', secret)
    .update(`${header}.${payload}`)
    .digest();
  const given = Buffer.from(signature, 'base64url');
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
    return null;
  }

  let claims;
  try {
    claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (claims === null || typeof claims !== 'object' || Array.isArray(claims)) {
    return null;
  }
  if (typeof claims.uid !== 'string' || claims.uid.length === 0) return null;
  if (typeof claims.exp !== 'number') return null;
  if (claims.exp + CLOCK_SKEW_SECONDS < Math.floor(Date.now() / 1000)) {
    return null;
  }

  return {
    uid: claims.uid,
    email: typeof claims.email === 'string' ? claims.email : '',
    displayName: typeof claims.name === 'string' ? claims.name : '',
    photoUrl: typeof claims.picture === 'string' ? claims.picture : '',
  };
}
