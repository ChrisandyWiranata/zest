import { applyCors, isOriginAllowed } from '../lib/cors.js';
import {
  applySecurityHeaders,
  publicErrorMessage,
  sendError,
  sendJson,
} from '../lib/http.js';
import { clientIp, limiterFromEnv } from '../lib/rateLimit.js';
import { needsAuth } from '../lib/routes.js';
import { requireUser } from '../lib/auth.js';
import { handleContent } from './content.js';
import { handleMe } from './me.js';

const limiter = limiterFromEnv();

/**
 * Satu-satunya entry point API. Routing dilakukan di dalam supaya kontrak
 * dengan Flutter hanya di satu tempat, dan handler yang sama bisa dipakai
 * oleh Vercel maupun server Node lokal (scripts/serve.js).
 */
export async function handle(req, res) {
  applyCors(req, res);
  applySecurityHeaders(res);

  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    res.end();
    return;
  }

  if (!isOriginAllowed(req)) {
    return sendError(res, 403, 'Origin tidak diizinkan.');
  }

  if (limiter) {
    const verdict = limiter.check(clientIp(req));
    if (!verdict.allowed) {
      res.setHeader('Retry-After', String(verdict.retryAfterSeconds));
      return sendError(res, 429, 'Terlalu banyak permintaan. Coba lagi nanti.');
    }
  }

  const url = new URL(req.url ?? '/', 'http://localhost');
  const { pathname, searchParams } = url;

  try {
    if (pathname === '/api/health') {
      return sendJson(res, 200, { ok: true, time: new Date().toISOString() });
    }

    // Konten & /api/me/* wajib idToken yang sah — katalog tidak lagi bisa
    // dibaca anonim (address bar/curl tanpa token → 401). Verifikasi dilakukan
    // sekali di sini; handler di bawah memakai req.user.
    if (needsAuth(pathname)) {
      req.user = await requireUser(req);
    }

    if (pathname.startsWith('/api/me/')) {
      return await handleMe(req.method, pathname, searchParams, req, res);
    }

    if (req.method !== 'GET') {
      return sendError(res, 405, `Metode ${req.method} tidak didukung.`);
    }

    return await handleContent(pathname, searchParams, res);
  } catch (error) {
    const status = Number.isFinite(error?.status) ? error.status : 500;
    if (status >= 500) {
      console.error('[zest-api]', error);
    }
    return sendError(res, status, publicErrorMessage(error));
  }
}

export default handle;
