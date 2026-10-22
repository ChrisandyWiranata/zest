const allowlist = (process.env.ALLOWED_ORIGINS ?? '')
  .split(',')
  .map((value) => value.trim().replace(/\/+$/, ''))
  .filter(Boolean);

function resolveOrigin(req) {
  const origin = req.headers?.origin ?? req.headers?.Origin ?? '';
  return origin.replace(/\/+$/, '');
}

/**
 * CORS allowlist. Origin yang tidak terdaftar tidak diberi header apa pun,
 * sehingga browser memblokir responsnya. Saat ALLOWED_ORIGINS kosong,
 * semua origin ditolak except request tanpa Origin (curl, health check).
 */
export function applyCors(req, res) {
  const origin = resolveOrigin(req);
  if (origin && allowlist.includes(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');
  return origin;
}

export function isOriginAllowed(req) {
  const origin = resolveOrigin(req);
  if (!origin) return true;
  return allowlist.includes(origin);
}
