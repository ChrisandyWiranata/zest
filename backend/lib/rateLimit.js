/**
 * Rate limit per-IP (fixed window, in-memory).
 *
 * Karena backend jalan di Vercel Functions (satu isolate per instance hangat),
 * limit ini bersifat per-instance — lapisan pertama saja. Proteksi edge yang
 * sesungguhnya datang dari Vercel WAF (dikonfigurasi di dashboard).
 *
 * Env: RATE_LIMIT_PER_MINUTE (default 120; 0 = matikan).
 */

export class RateLimiter {
  /**
   * @param {{limit?: number, windowMs?: number, maxEntries?: number, now?: () => number}} options
   */
  constructor({ limit = 120, windowMs = 60_000, maxEntries = 5000, now = Date.now } = {}) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.maxEntries = maxEntries;
    this.now = now;
    /** @type {Map<string, {count: number, resetAt: number}>} */
    this.windows = new Map();
  }

  /** @param {string} ip */
  check(ip) {
    const now = this.now();
    this.#prune(now);

    let entry = this.windows.get(ip);
    if (!entry || now >= entry.resetAt) {
      entry = { count: 0, resetAt: now + this.windowMs };
      this.windows.set(ip, entry);
      // Map mempertahankan urutan insert; kalau masih melebihi batas,
      // buang entri tertua supaya memori tidak bisa dibengkakkan lewat IP acak.
      if (this.windows.size > this.maxEntries) {
        const oldest = this.windows.keys().next().value;
        if (oldest !== ip) this.windows.delete(oldest);
      }
    }

    if (entry.count >= this.limit) {
      return {
        allowed: false,
        retryAfterSeconds: Math.max(1, Math.ceil((entry.resetAt - now) / 1000)),
      };
    }

    entry.count += 1;
    return { allowed: true, remaining: this.limit - entry.count };
  }

  #prune(now) {
    for (const [ip, entry] of this.windows) {
      if (now >= entry.resetAt) this.windows.delete(ip);
    }
  }
}

/**
 * IP klien. Di Vercel, `x-real-ip` dan `x-forwarded-for` di-set oleh platform
 * dan tidak bisa dipalsukan klien; di server lokal header itu tidak ada, jadi
 * jatuh ke socket (semua request lokal berbagi satu window — cukup untuk dev).
 */
export function clientIp(req) {
  const realIp = req.headers?.['x-real-ip'];
  if (typeof realIp === 'string' && realIp.trim()) return realIp.trim();

  const forwarded = req.headers?.['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }

  return req.socket?.remoteAddress ?? 'unknown';
}

/** Bangun limiter dari env; null bila dimatikan (`RATE_LIMIT_PER_MINUTE=0`). */
export function limiterFromEnv(env = process.env) {
  const raw = (env.RATE_LIMIT_PER_MINUTE ?? '').trim();
  const limit = raw === '' ? 120 : Number(raw);
  if (!Number.isFinite(limit) || limit <= 0) return null;
  return new RateLimiter({ limit });
}
