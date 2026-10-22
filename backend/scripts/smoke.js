import { createServer } from 'node:http';

import { handle } from '../api/index.js';

const server = createServer((req, res) => {
  handle(req, res).catch((error) => {
    console.error(error);
    res.statusCode = 500;
    res.end(JSON.stringify({ error: String(error) }));
  });
});

await new Promise((resolve) => server.listen(0, resolve));
const base = `http://127.0.0.1:${server.address().port}`;

let failures = 0;

async function check(name, { path, method = 'GET', token, origin, body, expect }) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (origin) headers.Origin = origin;
  if (body) headers['Content-Type'] = 'application/json';

  const res = await fetch(`${base}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const ok = res.status === expect;
  if (!ok) failures += 1;

  let detail = '';
  try {
    const json = JSON.parse(text);
    if (json.categories) detail = `${json.categories.length} kategori`;
    else if (json.words) detail = `${json.words.length} kata`;
    else if (json.videos) detail = `${json.videos.length} video`;
    else if (json.error) detail = json.error;
  } catch {
    detail = text.slice(0, 80);
  }

  console.log(
    `${ok ? 'PASS' : 'FAIL'}  ${name}\n      ${method} ${path} -> ${res.status} (harap ${expect})  ${detail}`,
  );
  return { ok, res, json: safeJson(text) };
}

function safeJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function skip(name, reason) {
  console.log(`SKIP  ${name}\n      ${reason}`);
}

const allowed = process.env.ALLOWED_ORIGINS?.split(',')[0]?.trim();
const token = process.env.SMOKE_TOKEN?.trim();

await check('health (publik)', { path: '/api/health', expect: 200 });

// Konten bukan lagi publik: anonim harus 401.
await check('kategori tanpa token', { path: '/api/categories', expect: 401 });
await check('kosakata tanpa token', { path: '/api/vocab?category=n5', expect: 401 });
await check('video tanpa token', { path: '/api/videos?category=n5', expect: 401 });

await check('progress tanpa token', {
  path: '/api/me/progress?categories=n5',
  origin: allowed,
  expect: 401,
});

await check('progress dengan token palsu', {
  path: '/api/me/progress?categories=n5',
  token: 'not-a-real-jwt',
  origin: allowed,
  expect: 401,
});

await check('session token cacat ditolak', {
  path: '/api/categories',
  token: 'zest_session.abc.def.ghi',
  expect: 401,
});

await check('sync tanpa token', {
  path: '/api/me/sync',
  method: 'POST',
  body: { stats: { total: 999999 } },
  origin: allowed,
  expect: 401,
});

await check('origin tidak di allowlist', {
  path: '/api/categories',
  origin: 'https://evil.example.com',
  expect: 403,
});

await check('endpoint tidak dikenal', {
  path: '/api/tidak-ada',
  origin: allowed,
  expect: 404,
});

if (!token) {
  const reason =
    'SMOKE_TOKEN tidak diset — cek login (katalog 200, validasi 400) dilewati.\n      ' +
    'Isi SMOKE_TOKEN dengan Google idToken asli (dev) untuk menjalankannya.';
  skip('kategori dengan token', reason);
  skip('kosakata dengan token', reason);
  skip('video dengan token', reason);
  skip('kategori tanpa parameter (butuh token)', reason);
  skip('session token diterima & TTL tidak diperpanjang', reason);
} else {
  const cats = await fetch(`${base}/api/categories`, {
    headers: { Authorization: `Bearer ${token}` },
  }).then((r) => r.json());
  const firstSlug = cats.categories?.[0]?.category ?? 'n5';

  await check('kategori dengan token', {
    path: '/api/categories',
    token,
    expect: 200,
  });

  await check('kosakata dengan token', {
    path: `/api/vocab?category=${encodeURIComponent(firstSlug)}`,
    token,
    expect: 200,
  });

  await check('video dengan token', {
    path: `/api/videos?category=${encodeURIComponent(firstSlug)}`,
    token,
    expect: 200,
  });

  await check('kategori tanpa parameter (butuh token)', {
    path: '/api/vocab',
    token,
    expect: 400,
  });

  // Session token web: terbit saat profile memakai idToken Google, lalu bisa
  // dipakai sendiri — dan penerbitan ulang TIDAK terjadi (TTL menempel login).
  const profile = await check('profile menerbitkan sessionToken', {
    path: '/api/me/profile',
    method: 'POST',
    token,
    origin: allowed,
    body: { email: 'smoke@example.com', displayName: 'Smoke' },
    expect: 200,
  });
  const sessionToken = profile.json?.sessionToken;

  if (!sessionToken) {
    skip(
      'session token diterima & TTL tidak diperpanjang',
      'respons profile tidak memuat sessionToken (SESSION_SECRET kosong?)',
    );
  } else {
    await check('session token diterima', {
      path: '/api/categories',
      token: sessionToken,
      expect: 200,
    });

    const again = await check('profile dengan session TANPA terbitkan ulang', {
      path: '/api/me/profile',
      method: 'POST',
      token: sessionToken,
      origin: allowed,
      body: { email: 'smoke@example.com', displayName: 'Smoke' },
      expect: 200,
    });
    if (again.json?.sessionToken) {
      failures += 1;
      console.log(
        'FAIL  session token tidak boleh diperpanjang oleh reload/kunjungan\n' +
          '      (respons profile kedua masih memuat sessionToken)',
      );
    }
  }
}

server.close();

console.log(failures === 0 ? '\nSemua smoke test lulus.' : `\n${failures} smoke test gagal.`);
process.exit(failures === 0 ? 0 : 1);
