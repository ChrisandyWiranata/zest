import { requireUser } from '../lib/auth.js';
import { nowSeconds, readJsonBody, sendError, sendJson } from '../lib/http.js';
import { createSessionToken } from '../lib/session.js';
import {
  fetchSrs,
  fetchStats,
  fetchWatched,
  findMeta,
  putMeta,
  upsertUser,
  writeSync,
} from '../lib/turso.js';
import { parseCategories, validateSyncPayload } from '../lib/validate.js';

/**
 * User terverifikasi. Normalnya sudah diisi gerbang auth `api/index.js`
 * (`req.user`); fallback verifikasi sendiri supaya handler ini tetap aman bila
 * dipanggil langsung.
 */
async function currentUser(req) {
  return req.user ?? (await requireUser(req));
}

/** POST /api/me/profile — upsert user, laporkan apakah ini login pertama. */
async function profile(req, res) {
  const user = await currentUser(req);
  const body = await readJsonBody(req);
  const now = nowSeconds();

  const existing = await findMeta(user.uid);
  const firstTime = existing.length === 0;

  // Klaim idToken yang sudah diverifikasi selalu didahulukan; body client
  // hanya fallback bila klaim tidak ada di token.
  await upsertUser(
    {
      uid: user.uid,
      email: user.email || body.email || '',
      displayName: user.displayName || body.displayName || '',
      photoUrl: user.photoUrl || body.photoUrl || '',
    },
    now,
  );
  await putMeta(user.uid, 1, now);

  const response = { firstTime, serverNow: now, uid: user.uid };
  // Session token hanya diterbitkan saat credential Google asli baru saja
  // diverifikasi (kind 'google') — reload dengan session token lama TIDAK
  // memperpanjang masa berlaku, jadi hari kedua user kembali ditawari
  // One Tap / halaman login.
  if (user.kind === 'google') {
    const sessionToken = createSessionToken(user);
    if (sessionToken) response.sessionToken = sessionToken;
  }
  return sendJson(res, 200, response);
}

/**
 * GET /api/me/progress?categories=a,b,c — satu round-trip untuk seluruh data
 * yang dibutuhkan hydrate(): stats, kartu SRS, dan video yang ditonton.
 */
async function progress(req, res, searchParams) {
  const user = await currentUser(req);
  const categories = parseCategories(searchParams.get('categories'));

  const statRows = await fetchStats(user.uid);
  const stats = statRows[0] ?? null;

  const srs = {};
  const watched = {};
  for (const category of categories) {
    srs[category] = {};
    for (const row of await fetchSrs(user.uid, category)) {
      const key = row.mastery_key;
      if (!key) continue;
      srs[category][key] = {
        n: row.n,
        interval: row.interval_days,
        ease: row.ease,
        due: row.due,
      };
    }
    watched[category] = (await fetchWatched(user.uid, category))
      .map((row) => row.video_key)
      .filter(Boolean);
  }

  return sendJson(res, 200, { stats, srs, watched, serverNow: nowSeconds() });
}

/** POST /api/me/sync — satu payload untuk stats + SRS + watched semua kategori. */
async function sync(req, res) {
  const user = await currentUser(req);
  const payload = validateSyncPayload(await readJsonBody(req));
  const updatedAt = nowSeconds();

  await writeSync(user.uid, { ...payload, updatedAt });

  return sendJson(res, 200, { ok: true, updatedAt });
}

export async function handleMe(method, pathname, searchParams, req, res) {
  if (pathname === '/api/me/profile' && method === 'POST') return profile(req, res);
  if (pathname === '/api/me/progress' && method === 'GET') {
    return progress(req, res, searchParams);
  }
  if (pathname === '/api/me/sync' && method === 'POST') return sync(req, res);

  return sendError(res, 404, `Endpoint tidak dikenal: ${pathname}`);
}
