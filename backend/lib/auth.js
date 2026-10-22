import { createRemoteJWKSet, jwtVerify, errors as joseErrors } from 'jose';
import { SESSION_PREFIX, verifySessionToken } from './session.js';

const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];

const rawAudiences = process.env.GOOGLE_AUDIENCES ?? '';
const audiences = rawAudiences
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

if (audiences.length === 0) {
  throw new Error(
    'GOOGLE_AUDIENCES wajib diset: daftar client ID Google yang sah, dipisah koma.',
  );
}

const jwks = createRemoteJWKSet(new URL(JWKS_URL));

export class UnauthorizedError extends Error {
  constructor(message) {
    super(message);
    this.name = 'UnauthorizedError';
    this.status = 401;
  }
}

function bearerToken(req) {
  const header = req.headers?.authorization ?? req.headers?.Authorization ?? '';
  if (!header.toLowerCase().startsWith('bearer ')) {
    throw new UnauthorizedError('Header Authorization dengan Bearer token wajib ada.');
  }
  const token = header.slice(7).trim();
  if (!token) {
    throw new UnauthorizedError('Bearer token kosong.');
  }
  return token;
}

/**
 * Verifikasi bukti identitas dan kembalikan klaim yang sudah dipercaya.
 *
 * Dua jenis token diterima:
 * - `zest_session.*` → session token buatan server (lihat lib/session.js);
 *   dipakai web agar sesi reload bertahan ≤1 hari tanpa prompt Google.
 * - lainnya → Google idToken (JWKS + audience + issuer).
 *
 * `uid` selalu diambil dari klaim token — nilai uid di body request diabaikan.
 * `kind` dipakai `POST /api/me/profile` untuk memutuskan penerbitan session
 * token (hanya saat credential Google asli baru saja diverifikasi).
 */
export async function requireUser(req) {
  const token = bearerToken(req);

  if (token.startsWith(SESSION_PREFIX)) {
    const claims = verifySessionToken(token);
    if (!claims) {
      throw new UnauthorizedError(
        'session token ditolak: kedaluwarsa atau tanda tangan salah.',
      );
    }
    return { ...claims, kind: 'session' };
  }

  try {
    const { payload } = await jwtVerify(token, jwks, {
      audience: audiences,
      issuer: ISSUERS,
      clockTolerance: 5,
    });
    if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
      throw new UnauthorizedError('Klaim sub tidak ada di idToken.');
    }
    return {
      uid: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : '',
      displayName: typeof payload.name === 'string' ? payload.name : '',
      photoUrl: typeof payload.picture === 'string' ? payload.picture : '',
      kind: 'google',
    };
  } catch (error) {
    if (error instanceof joseErrors.JOSEError || error instanceof UnauthorizedError) {
      throw new UnauthorizedError(`idToken ditolak: ${error.message}`);
    }
    throw error;
  }
}
