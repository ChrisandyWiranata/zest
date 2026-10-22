import assert from 'node:assert/strict';
import { test } from 'node:test';

import { RateLimiter, clientIp, limiterFromEnv } from '../lib/rateLimit.js';

test('mengizinkan sampai limit lalu menolak dengan retryAfter', () => {
  let now = 0;
  const limiter = new RateLimiter({ limit: 3, windowMs: 60_000, now: () => now });

  assert.equal(limiter.check('1.2.3.4').allowed, true);
  assert.equal(limiter.check('1.2.3.4').allowed, true);
  const third = limiter.check('1.2.3.4');
  assert.equal(third.allowed, true);
  assert.equal(third.remaining, 0);

  const blocked = limiter.check('1.2.3.4');
  assert.equal(blocked.allowed, false);
  assert.equal(blocked.retryAfterSeconds, 60);
});

test('window reset setelah windowMs lewat', () => {
  let now = 0;
  const limiter = new RateLimiter({ limit: 1, windowMs: 1000, now: () => now });

  assert.equal(limiter.check('ip').allowed, true);
  assert.equal(limiter.check('ip').allowed, false);

  now = 999;
  assert.equal(limiter.check('ip').allowed, false);
  now = 1000;
  assert.equal(limiter.check('ip').allowed, true);
});

test('IP berbeda punya window sendiri-sendiri', () => {
  const limiter = new RateLimiter({ limit: 1 });
  assert.equal(limiter.check('a').allowed, true);
  assert.equal(limiter.check('b').allowed, true);
  assert.equal(limiter.check('a').allowed, false);
  assert.equal(limiter.check('b').allowed, false);
});

test('entri kedaluwarsa dibersihkan dan map tidak melebihi maxEntries', () => {
  let now = 0;
  const limiter = new RateLimiter({ limit: 5, windowMs: 1000, maxEntries: 2, now: () => now });

  limiter.check('old');
  now = 1000; // 'old' kedaluwarsa
  limiter.check('new1');
  limiter.check('new2');
  assert.ok(limiter.windows.size <= 2, `ukuran map = ${limiter.windows.size}`);

  // IP lama yang sudah di-evict/bersih dianggap baru lagi (window segar).
  assert.equal(limiter.check('old').allowed, true);
});

test('evict membuang entri tertua, bukan IP yang baru saja dipakai', () => {
  const limiter = new RateLimiter({ limit: 5, maxEntries: 1 });
  assert.equal(limiter.check('old').allowed, true);
  assert.equal(limiter.check('new').allowed, true);
  assert.equal(limiter.windows.has('old'), false);
  assert.equal(limiter.windows.has('new'), true);
});

test('limiterFromEnv: default 120, 0 = mati, nilai tidak valid = mati', () => {
  assert.equal(limiterFromEnv({}).limit, 120);
  assert.equal(limiterFromEnv({ RATE_LIMIT_PER_MINUTE: '25' }).limit, 25);
  assert.equal(limiterFromEnv({ RATE_LIMIT_PER_MINUTE: '0' }), null);
  assert.equal(limiterFromEnv({ RATE_LIMIT_PER_MINUTE: '-1' }), null);
  assert.equal(limiterFromEnv({ RATE_LIMIT_PER_MINUTE: 'abc' }), null);
});

test('clientIp: x-real-ip > x-forwarded-for > socket', () => {
  assert.equal(
    clientIp({
      headers: { 'x-real-ip': '9.9.9.9', 'x-forwarded-for': '8.8.8.8, 1.1.1.1' },
      socket: { remoteAddress: '127.0.0.1' },
    }),
    '9.9.9.9',
  );
  assert.equal(
    clientIp({ headers: { 'x-forwarded-for': ' 8.8.8.8 , 1.1.1.1' } }),
    '8.8.8.8',
  );
  assert.equal(clientIp({ headers: {}, socket: { remoteAddress: '127.0.0.1' } }), '127.0.0.1');
  assert.equal(clientIp({ headers: {} }), 'unknown');
});
