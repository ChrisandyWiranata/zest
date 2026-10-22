# zest-api

Backend untuk aplikasi Flutter **zest**. Semua akses database Turso dan
verifikasi identitas user terjadi di sini, sehingga token read-write tidak
pernah ikut ter-bundle ke aplikasi.

Dihost di Vercel sebagai fungsi serverless Node (Express tidak dipakai).

## Endpoint

Semua endpoint wajib `Authorization: Bearer <token>` yang sah — **Google
idToken *atau* session token buatan server** (`zest_session.*`, lihat
"Session web" di bawah) — **kecuali `/api/health`** (monitoring). Tanpa token:
`401`. Origin browser di luar `ALLOWED_ORIGINS`: `403`.

| Method | Path | Query | Respons |
| --- | --- | --- | --- |
| GET | `/api/health` | — | `{ ok, time }` (publik) |
| GET | `/api/categories` | — | `{ categories: [...] }` |
| GET | `/api/vocab` | `category` (wajib) | `{ words: [...] }` |
| GET | `/api/videos` | `category` (wajib), `type` (opsional) | `{ videos: [...] }` |
| POST | `/api/me/profile` | `{ email, displayName, photoUrl }` | `{ ok, firstTime, serverNow, sessionToken? }` |
| GET | `/api/me/progress` | `categories=a,b,c` | `{ stats, srs, watched, serverNow }` |
| POST | `/api/me/sync` | `{ stats, srs, watched }` | `{ ok, updatedAt }` |

`uid` tidak pernah dibaca dari body request. Nilainya selalu diturunkan dari
klaim token yang sudah diverifikasi (`sub` idToken atau `uid` session token),
jadi klien tidak bisa menulis ke shard user lain.

### Session web (1 hari)

Sesi Google di web tidak bertahan antar-reload (prompt One Tap tidak
dijamin), jadi saat autentikasi memakai **Google idToken**, `POST
/api/me/profile` menerbitkan **`sessionToken`** (`zest_session.*`, HS256,
`SESSION_SECRET`, TTL `SESSION_TTL_HOURS` default 24 jam). Web menyimpannya di
localStorage dan memakainya sebagai Bearer sampai kedaluwarsa — reload dalam
sehari langsung masuk; hari ke-2 token ditolak (401) → web menawari One Tap
sekali, kalau nihil → halaman login. Token **tidak diperpanjang** oleh
reload/kunjungan (hanya penerbitan baru saat credential Google asli diverifikasi).
Klien lama/`native` mengabaikan field ini dan tetap memakai idToken (~1 jam)
dengan refresh senyap.

## Environment variables

Salin `.env.example` menjadi `.env.local` (gitignored), lalu isi:

| Key | Wajib | Keterangan |
| --- | --- | --- |
| `TURSO_URL` | ya | `libsql://<db>.turso.io` |
| `TURSO_TOKEN` | ya | token read-write, hanya di server |
| `GOOGLE_AUDIENCES` | ya | client ID web, iOS, Android dipisah koma |
| `ALLOWED_ORIGINS` | ya (prod) | origin frontend, dipisah koma, tanpa trailing slash. **Kosong = semua request ber-Origin ditolak** — jangan kosongkan di produksi |
| `RATE_LIMIT_PER_MINUTE` | tidak | default 120; `0` mematikan rate limit. Per-instance (di Vercel: per isolate hangat) |
| `SESSION_SECRET` | tidak* | secret HMAC untuk session token web (min. 16 karakter). **Tanpa ini fitur sesi nonaktif** — API tetap jalan penuh dengan idToken Google saja. Rotate = semua sesi web logout |
| `SESSION_TTL_HOURS` | tidak | masa berlaku session token dalam jam, default `24` (desimal didukung untuk uji) |

`GOOGLE_AUDIENCES` wajib memuat client ID **Android**: meskipun
`google_sign_in` di Android meminta idToken dengan audience web client,
backend memakai pemverifikasi `aud` yang menerima semua platform, jadi isi
ketiganya agar satu deployment melayani web + Android + iOS.

## Menjalankan lokal

```bash
npm install
npm test        # unit test rate limit, validasi payload, pesan error, routing
npm run migrate # pastikan 5 tabel user ada (idempoten)
npm run serve   # http://localhost:3000
npm run smoke   # cek 401 anonim, CORS, 404, health
```

`npm run smoke` adalah verifikasi utama: seluruhnya harus lulus sebelum deploy.
Karena katalog kini butuh token, cek "ber-token" (katalog 200, session token
dari profile → katalog 200, validasi 400) hanya jalan bila `SMOKE_TOKEN` diisi
Google idToken asli — kalau tidak, baris tersebut dicetak sebagai `SKIP`.

## Deploy ke Vercel

```bash
npm i -g vercel
cd backend
vercel link
vercel env add TURSO_URL production
vercel env add TURSO_TOKEN production
vercel env add GOOGLE_AUDIENCES production
vercel env add ALLOWED_ORIGINS production
vercel env add SESSION_SECRET production   # openssl rand -hex 32
vercel --prod
```

Setelah deploy, set `API_BASE_URL` di build Flutter ke domain backend.
Kalau frontend di-host di project Vercel terpisah, pasang juga rate rule WAF
(edge) untuk `/api/*` di dashboard — rate limit di kode hanya per-instance.

## Catatan keamanan

- **Rotasi token.** Token yang pernah ada di `.env` Flutter (dan ikut ter-bundle
  ke `build/web/assets/.env`) harus dicabut dari Turso, lalu token baru dibuat
  khusus untuk backend:
  ```bash
  turso db tokens create zest --expiration 30d
  turso db tokens invalidate <token-lama>
  ```
- Query memakai prepared statement dengan parameter; tidak ada string SQL yang
  disusun dari input pengguna.
- `uid` hanya dari `sub` token yang sudah diverifikasi signature-nya.
- **Katalog bukan lagi anonim**: `/api/categories|vocab|videos` ikut gerbang
  auth (`lib/routes.js: needsAuth`) — membuka URL di address bar/curl tanpa
  token → 401. Verifikasi idToken dilakukan sekali di `api/index.js`, hasilnya
  dipakai handler via `req.user`.
- Error 5xx selalu dibalas generik (`publicErrorMessage`) — detail internal
  hanya di log server; pesan 4xx dipertahankan untuk klien.
- Rate limit per-IP (`RATE_LIMIT_PER_MINUTE`) + validasi payload
  (`lib/validate.js`): batas kategori per request, batas entri sync, dan tipe
  field dicek sebelum menyentuh SQL (400, bukan 500).
- `/api/me/profile` memakai klaim idToken yang sudah diverifikasi lebih dulu;
  nilai email/nama/foto dari body client hanya fallback.
- **Session token** (`lib/session.js`): HMAC-SHA256 dengan `SESSION_SECRET`
  (tidak pernah ke klien), `timingSafeEqual`, batas ukuran token, klaim
  `exp` wajib — token basi/tanpa secret → 401. Penerbitan hanya saat
  autentikasi memakai idToken Google, sehingga TTL selalu menempel ke login
  terakhir.
- Setiap respons API membawa `X-Content-Type-Options: nosniff` dan
  `Referrer-Policy: no-referrer`. Header keamanan web (CSP dll.) ada di
  `vercel.json` root repo — bukan di sini.
