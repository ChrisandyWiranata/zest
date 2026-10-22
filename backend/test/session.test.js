import { createHmac } from 'node:crypto';
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  SESSION_PREFIX,
  createSessionToken,
  sessionTtlSeconds,
  verifySessionToken,
} from '../lib/session.js';

const SECRET = 'rahasia-testing-zest-'.repeat(2).slice(0, 40);

const USER = {
  uid: 'google-oauth2|118000000000000000000',
  email: 'ana@example.com',
  displayName: 'Ana',
  photoUrl: 'https://lh3.googleusercontent.com/a/photo',
};

function setEnv(t, vars) {
  for (const [key, value] of Object.entries(vars)) {
    const before = process.env[key];
    t.after(() => {
      if (before === undefined) delete process.env[key];
      else process.env[key] = before;
    });
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
}

function headerB64() {
  return Buffer.from('{"alg":"HS256","typ":"ZST"}')
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

/// Tandatangani payload mentah dengan secret aktif — untuk membuat token
/// "valid secara kriptografis" yang klaimnya sengaja cacat.
function signPayload(rawPayload, secret = SECRET) {
  const payload = Buffer.from(rawPayload)
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
  const input = `${headerB64()}.${payload}`;
  const sig = createHmac('sha256', secret)
    .update(input)
    .digest()
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
  return `${SESSION_PREFIX}${input}.${sig}`;
}

test('roundtrip: create lalu verify → klaim utuh', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET });
  const token = createSessionToken(USER);

  assert.ok(token.startsWith(SESSION_PREFIX));
  assert.equal(token.slice(SESSION_PREFIX.length).split('.').length, 3);

  const claims = verifySessionToken(token);
  assert.equal(claims.uid, USER.uid);
  assert.equal(claims.email, USER.email);
  assert.equal(claims.displayName, USER.displayName);
  assert.equal(claims.photoUrl, USER.photoUrl);
});

test('tanpa SESSION_SECRET (atau terlalu pendek) → fitur nonaktif', (t) => {
  setEnv(t, { SESSION_SECRET: undefined });
  assert.equal(createSessionToken(USER), null);

  setEnv(t, { SESSION_SECRET: 'pendek' });
  assert.equal(createSessionToken(USER), null);
  assert.equal(verifySessionToken(`${SESSION_PREFIX}a.b.c`), null);
});

test('uid wajib saat menerbitkan', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET });
  assert.equal(createSessionToken({ ...USER, uid: '' }), null);
  assert.equal(createSessionToken({ email: 'x@y.z' }), null);
});

test('verify → null bila secret berbeda', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET });
  const token = createSessionToken(USER);

  setEnv(t, { SESSION_SECRET: 'secret-lain-yang-panjang-sekali'.slice(0, 30) });
  assert.equal(verifySessionToken(token), null);
});

test('payload dimanipulasi → tanda tangan gagal → null', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET });
  const token = createSessionToken(USER);
  const rest = token.slice(SESSION_PREFIX.length);
  const [header, payload, sig] = rest.split('.');
  const bytes = Buffer.from(payload, 'base64url');
  bytes[0] = bytes[0] ^ 0x20; // ubah isi payload tanpa menandatangani ulang
  const tampered = `${SESSION_PREFIX}${header}.${bytes
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')}.${sig}`;

  assert.equal(verifySessionToken(tampered), null);
  assert.equal(verifySessionToken(token.replace(/.$/, 'x')), null);
});

test('token kedaluwarsa → null', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET, SESSION_TTL_HOURS: '1' });
  const token = createSessionToken(USER);

  const realNow = Date.now;
  Date.now = () => realNow() + 2 * 3600 * 1000; // lewati TTL + clock skew
  try {
    assert.equal(verifySessionToken(token), null);
  } finally {
    Date.now = realNow;
  }
  assert.notEqual(verifySessionToken(token), null, 'masih sah sebelum TTL');
});

test('klaim cacat yang ditandatangani benar tetap ditolak', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET });
  const now = Math.floor(Date.now() / 1000);

  assert.equal(verifySessionToken(signPayload('bukan-json')), null);
  assert.equal(verifySessionToken(signPayload('[]')), null);
  assert.equal(
    verifySessionToken(
      signPayload(JSON.stringify({ email: 'a@b.c', exp: now + 3600 })),
    ),
    null,
    'uid kosong',
  );
  assert.equal(
    verifySessionToken(
      signPayload(JSON.stringify({ uid: 'u1', exp: 'besok' })),
    ),
    null,
    'exp bukan number',
  );
  assert.equal(
    verifySessionToken(
      signPayload(JSON.stringify({ uid: 'u1', exp: now - 3600 })),
    ),
    null,
    'exp lampau',
  );
});

test('input sampah → null (tanpa throw)', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET });
  for (const bad of [
    null,
    undefined,
    42,
    '',
    'zest_session',
    'zest_session.a.b',
    'zest_session.a.b.c.d',
    `${SESSION_PREFIX}${headerB64()}.not-base64url-json.x`,
    'ya29a-google-style-jwt.tanpa.prefix',
    `${SESSION_PREFIX}${'a'.repeat(3000)}`,
  ]) {
    assert.equal(verifySessionToken(bad), null, `input: ${String(bad).slice(0, 40)}`);
  }
});

test('klaim panjang dipotong sesuai batas', (t) => {
  setEnv(t, { SESSION_SECRET: SECRET });
  const token = createSessionToken({
    ...USER,
    email: 'x'.repeat(1000),
    displayName: 'y'.repeat(1000),
    photoUrl: 'z'.repeat(5000),
  });
  const claims = verifySessionToken(token);

  assert.ok(claims.email.length <= 320);
  assert.ok(claims.displayName.length <= 256);
  assert.ok(claims.photoUrl.length <= 512);
});

test('sessionTtlSeconds: default 24 jam, env mengubah, minimal 60 detik', (t) => {
  setEnv(t, { SESSION_TTL_HOURS: undefined });
  assert.equal(sessionTtlSeconds(), 86400);

  setEnv(t, { SESSION_TTL_HOURS: '0.5' });
  assert.equal(sessionTtlSeconds(), 1800);

  setEnv(t, { SESSION_TTL_HOURS: '0' });
  assert.equal(sessionTtlSeconds(), 86400, 'angka tidak valid → default');

  setEnv(t, { SESSION_TTL_HOURS: '0.001' });
  assert.equal(sessionTtlSeconds(), 60, 'clamp minimum');
});
