# AGENTS.md

## Repo
Flutter app **zest** — Japanese-learning flashcard (SRS) + video lessons. Entry: `lib/main.dart`
(`ZestApp` → `AppShell` bottom-nav Beranda|Profil|Pengaturan, `IndexedStack`). The Pengaturan
destination only exists when a `SettingsStore` is passed (tests omit it unless they need it).
Feature code lives in `lib/features/<domain>/{pages,widgets,services,models}`; shared UI/theme in `lib/core`.

## Commands
After any change, run in order:
- `dart format lib test`
- `flutter analyze`
- `flutter test`  (fast — single-call runs the whole suite)
- Web build: `bash tool/build_web.sh` (jangan `flutter build web` polos — artefak
  butuh `vercel.json` tersalin dan `.env.local` dibuang)

Backend (`backend/`): `npm ci` (node_modules tidak di-commit), lalu
`npm test` (unit: rate limit, validasi payload, pesan error) dan
`npm run smoke` (integrasi, butuh `.env.local` + Turso hidup). Keduanya wajib
lulus sebelum deploy.

No CI, no pre-commit, no linters beyond stock `flutter_lints`.

## Tests (gotchas that bite)
- `test/widget_test.dart` sets `ambientEnabled = false` in `setUp`. AmbientParticles loops
  forever and would hang `pumpAndSettle`; all UI animations must be finite (skeletons are static, no shimmer).
- Default test surface is 800x600. The Profil page has **two** scrollables (ListView + GridView), so
  scroll via `find.descendant(of: find.byType(ProfilePage), matching: find.byType(Scrollable)).first`.
- Test user is `AppUser(uid: 'u1', email: 'ana@x.com', displayName: 'Ana')`; dashboard assertions match
  exact copy (`'Hai, Ana!'`, `'0 ulangan · 2 kata baru'`, `'1 video'`). If UI copy changes, update tests.
- Fakes `implements` real services (e.g. `_FakeVideoProgressStore`). Adding a method/getter to a service
  requires the same on its fake, or tests fail to compile.

## Env & backend (REST ke Node di Vercel, per-user shard)
- **Tidak ada lagi akses Turso dari klien.** `API_URL`/`TOKEN` sudah dihapus dari `.env`.
  Klien talking ke backend Node di `backend/` (lihat `backend/README.md`) via **Dio**,
  di `lib/core/network/api_client.dart`. Semua query SQL tinggal di server.
- Env dibaca lewat `AppConfig.read(key)` (`lib/config/app_config.dart`). Sumber tunggal = `.env`
  (terdaftar asset, jadi ikut ter-bundle). Dipakai oleh `ApiConfig`, `TtsConfig`, `AuthConfig`.
- **`.env` terdaftar sebagai asset dan isinya publik.** Karena itu `build/web/assets/.env` bisa
  diunduh siapa saja — karena itu jangan pernah menaruh secret di sana. Yang bocor sebelumnya bukan
  keberadaan `.env`, melainkan `TURSO_TOKEN` di dalamnya. `TURSO_URL`/`TURSO_TOKEN` hanya di
  `backend/.env.local` (gitignored). `test/env_secret_guard_test.dart` menegakkan aturan ini —
  jalankan kalau `.env` berubah.
- `main()` memanggil `loadDotEnv()` yang tidak melempar kalau `.env` hilang — `flutter_dotenv`
  melempar `FileNotFoundError` lewat `rootBundle`, dan tanpa guard aplikasi crash sebelum
  `runApp`. Jangan kembalikan `await dotenv.load()` mentah ke `main()`.
- `ApiClient.idToken` diisi `UserSession` pada login/restore (dikosongkan saat logout);
  endpoint `/api/me/*` akan 401 bila kosong. `ApiClient` melempar `ApiException` yang
  **mempertahankan pesan server apa adanya** — jangan ubah semua error jadi "periksa OAuth".
- **Keamanan backend** (jangan dilonggarkan): rate limit per-IP (`RATE_LIMIT_PER_MINUTE`,
  default 120/menit, `0` = mati; in-memory per-instance — WAF Vercel lapis kedua); validasi
  payload di `backend/lib/validate.js` (sync maks 20.000 entri, progress maks 64 kategori,
  tipe field wajib number/string → 400 bukan 500); pesan error 5xx selalu generik via
  `publicErrorMessage` (4xx tetap apa adanya); `/api/me/profile` memakai klaim idToken
  terverifikasi dulu, body client hanya fallback. Respons API bawa `nosniff` +
  `Referrer-Policy: no-referrer`.
- **Katalog bukan anonim**: semua `/api/*` wajib kecuali `/api/health` — gerbang auth di
  `backend/api/index.js` memakai `needsAuth()` (`backend/lib/routes.js`, satu sumber kebenaran
  route), hasil verifikasi disimpan di `req.user` (JWKS dicek sekali per request). Address
  bar/curl tanpa token → 401. Smoke: cek ber-token butuh env `SMOKE_TOKEN` (tanpa itu dicetak SKIP).
- **401 → auto-refresh** (kontrak klien): `ApiClient.onUnauthorized` diisi
  `session.reauthenticate` di `main.dart` (**sebelum** `session.restore()`). Native:
  refresh senyap (`auth.restore`) lalu `signIn` sekali bila token hasilnya basi — user
  **tidak** ter-logout; **web: coba prompt One Tap sekali** (credential segar + `exp`
  masih hidup + uid sama → `adopt` tanpa logout; kalau Google tak memberi credential →
  logout ke LoginPage; jangan pakai `signIn()` di web, token GIS deprecated). Selama
  restore membaca sesi tersimpan, `reauthenticate` diam (flag `_restoringFromSaved` —
  jalur sesi **web** tersimpan saja; cache native sudah selesai sinkron jadi tidak
  butuh flag) supaya 401 merambat ke `restore()` — fallback prompt cukup satu kali,
  tidak dobel.
  Retry request **hanya sekali dan hanya kalau token berubah**. Token dicek via
  `isIdTokenFresh()` (`lib/features/auth/services/id_token.dart`, baca klaim `exp` saja).
  Fakes `ApiClient` harus ikut punya field `onUnauthorized`.
- **Session token web (1 hari, web only)**: `POST /api/me/profile` menerbitkan
  `sessionToken` (HS256, prefix `zest_session.`, TTL `SESSION_TTL_HOURS` default 24 jam
  **sejak login Google terakhir** — reload/kunjungan TIDAK memperpanjang) **hanya saat
  autentikasi memakai Google idToken asli** (`kind:'google'` di `requireUser`;
  autentikasi session tidak menerbitkan token baru). Client web menyimpannya di
  SharedPreferences key **`session.web.v1`** dan `restore()` web membaca key ini DULU
  (tanpa prompt One Tap sama sekali kalau valid); 401 → key dibersihkan → fallback
  prompt sekali → nihil → LoginPage. Native mengabaikan key ini. `UserSession._keepSession`
  = simpan ke prefs + jadikan Bearer sesudahnya (Bearer pindah dari idToken Google ±1 jam
  ke session token). Backend butuh env **`SESSION_SECRET`** (min 16 karakter; fitur mati
  otomatis kalau kosong = perilaku lama) + opsional `SESSION_TTL_HOURS` — deploy:
  `vercel env add SESSION_SECRET production` (isi `openssl rand -hex 32`) sebelum
  `vercel --prod` di `backend/`.
- **Masuk home instan di mobile (`session.native.v1`)**: native TIDAK bergantung
  `signInSilently()` untuk *masuk* — profil terakhir (uid/email/nama/foto,
  **tanpa token**) disimpan di prefs key **`session.native.v1`** (ditulis `adopt` dan
  restore sukses via `_keepSession`; dihapus `logout()`). `restore()` native membaca
  cache ini → `value` di-set **sinkron sebelum `runApp`** → frame pertama = home,
  LoginPage tidak pernah sempat muncul walau `signInSilently()` null/timeout.
  Token Google menyusul lewat `_refreshNativeBackground` (`signInSilently` di
  background); gagal = **diam** — jangan pernah logout dari sini; 401 →
  `reauthenticate` yang menangani (dialog `signIn` sekali hanya kalau silent
  restore memang rusak di device). Key ini beda dengan `session.web.v1` dan tidak
  saling membaca.
- **Startup cepat**: `main()` TIDAK meng-await `session.restore()` — `runApp()` duluan,
  restore jalan di belakang (`unawaited`). Native **dengan** profil tersimpan:
  `value` ter-set sinkron (tanpa await) sehingga frame pertama = **home**; web dan
  native tanpa cache: frame pertama = LoginPage. `restore()` memakai
  `restoreTimeout` (default 4 detik; prompt One Tap web bisa tak pernah jawab)
  dan race guard: bila `adopt()` (credential web) menang duluan, restore tidak hydrate
  ulang dan tidak pernah menimpa `value` — termasuk dengan `null`. Hydrate jalan
  paralel: `syncProfile`(+migrate) ∥ `getCategories`+`fetchProgress`.
- **Header keamanan web (CSP dll.) = `vercel.json` di ROOT repo** (project terpisah dari
  API yang root-nya `backend/`). Kalau ganti host video (Wistia/DigitalOcean), domain
  Google, atau `API_BASE_URL`, update directive CSP di sana. ⚠️ `script-src` wajib
  memuat **`'wasm-unsafe-eval'`** — tanpa itu Chrome memblokir kompilasi
  `canvaskit.wasm`; `script-src` + `connect-src` wajib memuat **`https://www.gstatic.com`**
  dan `connect-src` wajib memuat **`https://fonts.gstatic.com`** — Flutter build default
  (`--web-resources-cdn`, ON) memuat canvaskit dari `www.gstatic.com/flutter-canvaskit/...`
  dan engine mengunduh font Roboto dari `fonts.gstatic.com`; tanpa ketiganya layar
  hitam/blank dengan error `blocked:csp` di Network (pernah terjadi dua kali — jangan
  dilepas). Alternatif self-host canvaskit: `flutter build web --no-web-resources-cdn`
  (canvaskit dari `'self'`), tapi fetch Roboto dari `fonts.gstatic.com` tetap hardcoded
  di engine jadi `connect-src` tetap butuh host itu. `media-src`
  wajib memuat `blob:` untuk video HLS/MSE. Project Vercel frontend
  root-nya `build/web` (lihat `build/web/.vercel/project.json`) sehingga root `vercel.json`
  **tidak ikut deploy** — build web WAJIB lewat `bash tool/build_web.sh` (copy
  `vercel.json` ke `build/web/` + buang `.env.local` dari artefak). Cek keberadaan header
  dengan `curl -I` setelah deploy.
- All-or-nothing sync: `flush()`/`pushAll()` mengirim **satu** `POST /api/me/sync`
  berisi stats + seluruh SRS + seluruh watched, dan baru membersihkan antrean lokal
  setelah server mengonfirmasi (retry-safe, `SyncStatus.error` bila gagal).
- `hydrateUserData` juga satu `GET /api/me/progress?categories=...`.
- Test memakai `FakeApiClient` (implements `ApiClient` dengan `get`/`post` + `idToken`);
  menambah method/getter ke `ApiClient` berarti fake ikut harus di-update.

## Google auth (platform quirk)
`AuthConfig.resolve()` in `lib/features/auth/services/google_auth_service.dart`:
- **web** → `clientId: webId`, `serverClientId: null` (google_sign_in_web/GIS asserts that
  `serverClientId` is unsupported on web and requires `clientId` or the
  `<meta name="google-signin_client_id">` tag in `web/index.html`).
  ⚠️ `GoogleSignInButton` (jalur lama) **tidak selalu mengisi `authentication.idToken`**
  di web. Kalau `idToken` kosong, konten tetap terbaca (endpoint publik) tapi progres
  akan 401 → user harus migrasi ke `renderButton` (GIS 7.x). Cek `AppUser.idToken`
  tidak kosong sebelum shipped.
- **Android / desktop** → `clientId: null`, `serverClientId: webId` (on Android the plugin
  interprets `clientId` as serverClientId and `requestIdToken` only accepts the web client id).
- iOS → `clientId: iosId`, `serverClientId: null`. Empty env strings are coerced to null.
- Env keys: `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_ANDROID_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`.
- **Web login wajib credential** (One Tap / tombol `renderButton`): `signIn()` di web memakai
  GIS token flow deprecated yang **tidak pernah menghasilkan idToken tanpa credential** —
  People API hanya bikin profil sintetis (403 → "Periksa konfigurasi OAuth"; sukses pun
  idToken kosong → backend 401). LoginPage web memakai `GoogleWebSignInButton`
  (conditional import `google_web_sign_in_button.dart`) + stream `AuthService.accountChanges`
  → `UserSession.adopt(user)`. Jangan kembalikan `session.login()` untuk jalur web.
  Checklist console: Authorized JavaScript origins memuat origin persis (localhost:port &
  domain Vercel), consent screen mode Testing → akun jadi Test user, Vercel `GOOGLE_AUDIENCES`
  memuat web client ID. People API tidak diperlukan.

## Local state (SharedPreferences, per-uid namespaces)
Progress is stored per user under uid-prefixed keys — do not change without a migration plan.
Dua kunci **lintas-user** (bukan per-uid, milik `UserSession`): `session.web.v1`
(session token web) dan `session.native.v1` (profil mobile untuk home instan):
`xp.$uid.*`, `srs.$uid.<category>.<id>`, `watched_video.$uid.<category>.<id>`,
`resume_video.$uid.<category>.<id>`, `sync.$uid.last_at`, `settings.$uid.*` (`new_per_session`,
`session_cap`, `daily_new_budget`, `auto_speak`, `first_review_days`, `interval_factor`,
`max_interval_days`, `mature_days`), and `settings.$uid.daily_new.<epochDay>` (counter
kata baru yang diperkenalkan hari ini, di-increment oleh `StudyPage` saat kata baru pertama kali
digrading). `SettingsStore` (`lib/features/settings/services/settings_store.dart`) is a
`ValueNotifier<SettingsData>`; default = `kNewCap`/`kSessionCap` (10/20), budget 0 = tanpa batas.
SRS knobs default 1 / 2.5 / 60 / 21 (`first_review_days` / `interval_factor` /
`max_interval_days` / `mature_days`) — `srsGood` accepts `firstInterval`/`maxInterval`/`defaultEase`,
`isMature` accepts `matureDays`; UI pages pass `settings?.value.*` (fallback = scheduler consts).
Hafal counts (home, category, profil) all use the same `matureDays`.
`buildQueue` takes `freshCap` (override kata baru/sesi, menghormati sisa jatah harian) — defaults
bukan `kNewCap` bila `settings == null`, jadi call-site lama & test copy tidak berubah.
Counters are derived by prefix scan (`XPStore`, `VideoProgressStore.countWatched`), not stored aggregates.

`ProgressSync` (`lib/features/users/services/progress_sync.dart`): `ValueNotifier<SyncStatus> status`;
`flush()` menghapus antrean lokal hanya setelah POST sukses (retry-safe). Dipicu saat lifecycle
paused/inactive dan saat masuk tab Profil. `lastSyncAt` tersimpan di `sync.$uid.last_at`.
Interface berupa `sync.*Changed(...)`. `pushAll(...)` (tombol "Sinkronkan progres" di Profil)
mengirim seluruh data lokal SRS/watched/stats per kategori ke backend tanpa menghapus data lokal —
oper `XpStore`/`SrsStore`/`VideoProgressStore` asli + `getCategories`.
`migrateLegacyUserData` (sekali, hanya saat `POST /api/me/profile` balas `firstTime: true`) dan
`hydrateUserData` sekarang memakai `ApiUserRepo`. Hapus kunci legacy setelah sukses, seperti sebelumnya.

## TTS (VOICEVOX, opsional)
- Produksi = `AssetTtsService` (`lib/features/tts/services/`): memutar MP3 offline dari
  `assets/audio/{hash}.mp3` (didaftarkan di `pubspec.yaml`, index `assets/audio/index.json`).
  Tanpa jaringan. Tombol speaker disembunyikan bila bacaan tidak ada di indeks — `TtsService.has()`
  dicheck lewat `FutureBuilder` di `SpeakButton` (`lib/core/widgets/speak_button.dart`).
- Regenerate audio (`tool/generate_tts.py`): baca daftar `read` dari Turso, synth VOICEVOX
  lokal (`127.0.0.1:50021`) → MP3 64k mono 24kHz via ffmpeg → tulis file baru (hash dari bacaan,
  resumable) + index.json. Butuh credential Turso + `VOICEVOX_SPEAKER_ID`, VOICEVOX jalan, ffmpeg.
  ⚠️ Script ini tool sekali pakai yang masih membaca Turso langsung — **jangan** dipindah ke
  `lib/`, dan jangan pernah dyinginkan ulang token database ke `.env` Flutter.
- Dev fallback = `VoicevoxTtsService`: aktif hanya saat `VOICEVOX_BASE_URL` terisi di env
  (default speaker id 2 = 四国めたん). 2-step HTTP `/audio_query` → `/synthesis` (WAV) play via
  `audioplayers`, cache memori key `speaker|text`; errors swallowed. Debug Android manifest allows
  cleartext HTTP (dev server LAN); release stays blocked.
- Test gotcha: constructing `audioplayers.AudioPlayer` hangs on a `creatingCompleter` that never
  resolves without a plugin. `VoicevoxTtsService` accepts an injected `playFn` dan
  `AssetTtsService` menerima `playAsset` + `index` yang di-inject; unit tests never construct the
  player. Widget tests pass `tts: null` → button hidden; don't call `speak` with a real player.

## Logo & launcher icons
Logo sumber: `assets/icon/logo-zest.png` (transparan, glyph merah torii). Sumber square 1024²
(`logo-zest-1024.png` transparan untuk adaptive foreground/in-app, `logo-zest-bg-1024.png` penuh
`#121214` untuk iOS/web/Android legacy) di-generate oleh `tool/make_logo_icons.swift` (`swift
tool/make_logo_icons.swift`) dan keduanya diberi outline hitam di sekeliling glyph. Border kotak
logo di dalam app (sidebar & login) memakai `Colors.black`. Launcher icons semua platform dihasilkan ulang via
`dart run flutter_launcher_icons` (konfigurasi blok `flutter_launcher_icons:` di ujung
`pubspec.yaml`; web juga menulis `web/favicon.png` + `web/icons/*` + update `web/manifest.json`).
In-app: `_ZestLogo` (sidebar) & halaman login memakai `Image.asset('assets/icon/logo-zest.png')`
(asset terdaftar di pubspec). Ubah logo → regenerate sources + launcher icons + pastikan copy
teks 'Zest' di test tetap hijau.

## Platform
Android is the primary target (`android:label="Zest"`; iOS display name already "Zest").
Layout is **adaptive by width** (`lib/core/layout/adaptive_layout.dart`): below `AdaptiveLayout.wideBreakpoint`
(900) you get the compact mobile shell (bottom-nav, one-column); at/above it the wide face
(sidebar `ZestSidebar`, centered content ≤ `AdaptiveLayout.contentMaxWidth` 1180, multi-column grids).
Never reintroduce a fixed `<1000px` wrapper around the app. Widget tests run at 800×600 (compact),
so existing copy assertions are safe; wide tests set `tester.view.physicalSize` (e.g. 1400×900, dpr 1)
and reset via `addTearDown`. New layout branches must keep the exact same user-facing copy.
- Tab Video: **web wide saja** (`kIsWeb && AdaptiveLayout.isWide`) → split view `VideoSplitView`
  (sidebar daftar video per bab + filter di kiri, player inline di kanan, placeholder
  'Pilih video untuk mulai menonton'); mobile/desktop app tetap flow lama (daftar → push
  `VideoPlayerPage`). Isi player diextract jadi `VideoPlayerView` (dipakai kedua jalur);
  toggle pill dipindah ke `VideoModeToggle` (`lib/features/videos/widgets/video_mode_toggle.dart`).
  Test split view = `test/video_split_view_test.dart` memakai `playerBuilder` injection —
  jangan pernah pump `Chewie`/`video_player` di test. `VideoPlayerView` punya seam
  `playerBuilder` sendiri (test: `test/video_player_view_test.dart`).
  Aturan: toggle/auto watched harus **repaint sebelum `sync.flush()`** — jangan await
  sync dulu baru setState (bug: tombol/sidebar baru berubah setelah refresh).