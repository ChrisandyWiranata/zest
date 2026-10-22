export function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(body);
}

export function sendError(res, status, message) {
  sendJson(res, status, { error: message });
}

/**
 * Pesan error yang aman dikirim ke klien: pesan 4xx dipertahankan (kontrak
 * dengan ApiException di Flutter), 5xx selalu generik — detail internal
 * (SQL, URL Turso, stack) hanya boleh masuk log server.
 */
export function publicErrorMessage(error) {
  const status = Number.isFinite(error?.status) ? error.status : 500;
  if (status >= 500) return 'Terjadi kesalahan di server.';
  if (typeof error?.message === 'string' && error.message.trim()) return error.message;
  return 'Terjadi kesalahan di server.';
}

/** Header keamanan dasar untuk semua respons API. */
export function applySecurityHeaders(res) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
}

export async function readJsonBody(req, { limitBytes = 4 * 1024 * 1024 } = {}) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limitBytes) {
      const error = new Error('Payload terlalu besar.');
      error.status = 413;
      throw error;
    }
    chunks.push(chunk);
  }
  if (chunks.length === 0) return {};
  const raw = Buffer.concat(chunks).toString('utf8').trim();
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    const error = new Error('Body bukan JSON yang valid.');
    error.status = 400;
    throw error;
  }
}

export function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}
