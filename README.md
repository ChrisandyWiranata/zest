<div align="center">

# 🔥 Zest

**Aplikasi belajar bahasa Jepang — flashcard SRS, video lesson, XP & streak.**
*Sesi singkat tiap hari · offline-first · sinkron ke akun Google.*

![Flutter](https://img.shields.io/badge/Flutter-Platform-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-2C2C30)
![Node](https://img.shields.io/badge/Node.js-Backend-339933?logo=nodedotjs&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-Deploy-000000?logo=vercel&logoColor=white)
![Turso](https://img.shields.io/badge/Turso-Database-4FF8D2?logo=turso&logoColor=black)

</div>

> **Zest** membantu kamu konsisten belajar bahasa Jepang lewat dua pilar: **flashcard SRS** yang menjadwalkan ulang kartu secara otomatis, dan **video lesson** terstruktur per bab. Progres tersimpan dulu di perangkat (offline-first), lalu disinkronkan ke akun Google — aman saat ganti perangkat.

## ✨ Fitur

- **🔐 Masuk sekali pakai Google** — tanpa pendaftaran manual. Web memakai One Tap / tombol GIS, Android & iOS silent restore; web sesi bertahan **1 hari** (session token), mobile **langsung ke Beranda** dari profil tersimpan — layar login tidak muncul lagi.
- **📚 Flashcard SRS** — kartu dibalik 3D (kata + bacaan → arti + contoh kalimat), jawab *Sudah hafal* / *Belum hafal*. Penjadwalan otomatis (interval × kemudahan, jatuh tempo per kartu), batas kata baru per sesi, kartu salah diulang lagi di sesi yang sama. Ringkasan sesi + **konfeti** saat naik level.
- **🎥 Video lesson** — per kategori & bab, filter **Gabung | Bunpou | Kosakata**, *lanjut menonton* dari posisi terakhir, penanda **Sudah ditonton** otomatis (video selesai) atau manual. Di layar lebar: split view daftar + player.
- **🏆 XP, level & streak** — poin per jawaban benar, level tiap kelipatan XP, streak harian. Statistik di Beranda & Profil: XP hari ini, kata hafal, video ditonton.
- **🔊 Pengucapan offline** — audio VOICEVOX di-bundle sebagai MP3 (~10 MB) → tombol speaker berfungsi tanpa internet; bacaan tanpa audio otomatis disembunyikan.
- **☁️ Sinkronisasi progres** — *all-or-nothing*: satu request berisi stats + seluruh SRS + seluruh watched. Otomatis saat app masuk latar belakang & saat buka Profil, plus tombol manual. Antrean lokal hanya dibersihkan setelah server konfirmasi.
- **📴 Offline-first** — seluruh XP, jadwal SRS, dan status video tersimpan per-akun di perangkat; belajar tanpa internet, sinkron menyusul.
- **🌗 Dark-minimalis adaptif** — aksen merah torii, kontras teks WCAG AA; **bottom nav** di layar sempit & **sidebar** di ≥ 900 px, partikel ambient, UI berbahasa Indonesia.

## 🛠 Tech stack

| Lapisan | Pilihan |
|---|---|
| Aplikasi | **Flutter** (Dart ^3.12) — Android, iOS, Web |
| State & data lokal | `ValueNotifier` + service (tanpa framework state); SharedPreferences per-akun |
| Networking | **Dio** (`ApiClient`) + auto-retry 401 saat token segar |
| Video | `video_player` + `chewie` (streaming HLS) |
| Auth | `google_sign_in` (Android/iOS), Google Identity Services (web) |
| Backend | **Node.js ≥ 20** — fungsi serverless di **Vercel** (tanpa Express) |
| Database | **Turso** (libSQL) — shard per user; klien tidak pernah menyentuh DB |
| Keamanan | Verifikasi Google ID token via JWKS (`jose`) + session token HS256 (TTL 24 jam) |
| TTS | VOICEVOX — MP3 offline di-bundle; mode live untuk dev |

## 🚀 Menjalankan lokal

**Prasyarat:** Flutter SDK, Node ≥ 20, client ID Google OAuth, akun Turso.

```bash
# Aplikasi
git clone https://github.com/ChrisandyWiranata/zest.git
cd zest
flutter pub get
cp .env.example .env          # isi GOOGLE_*_CLIENT_ID (nilai publik, bukan secret)
flutter run
```

```bash
# Backend (terminal terpisah)
cd backend
npm ci
cp .env.example .env.local    # isi TURSO_URL + TURSO_TOKEN (gitignored)
npm run serve                 # http://localhost:3000
```

## 🧪 Perintah penting

| Perintah | Fungsi |
|---|---|
| `dart format lib test` | Format kode |
| `flutter analyze` | Static analysis — wajib nol isu |
| `flutter test` | Unit + widget test (seluruh suite) |
| `npm test` | Test unit backend |
| `npm run smoke` | Test integrasi backend (butuh Turso hidup) |
| `bash tool/build_web.sh` | Build web siap deploy (salin `vercel.json`, buang `.env` lokal) |

**Deploy:** frontend `vercel --prod` dari artefak `build/web` (hasil script di atas), backend `vercel --prod` dari `backend/`.

## 📂 Struktur proyek

```text
zest/
├── lib/
│   ├── features/            # auth · home · vocab · videos · categories
│   │                        # profile · settings · users · tts · progress
│   ├── core/                # layout adaptif, tema, widget bersama, ApiClient
│   └── config/              # AppConfig — baca .env (asset publik, tanpa secret)
├── backend/                 # API serverless Node (Vercel)
│   ├── api/                 # handler per endpoint
│   └── lib/                 # routes, validasi, JWKS, db Turso
├── assets/                  # audio TTS (MP3) + ikon
├── test/                    # unit & widget test
├── tool/                    # build_web.sh · generate_tts.py · make_logo_icons.swift
├── docs/PRODUCT_DESIGN.md   # alur produk, fitur, data, desain
└── AGENTS.md                # aturan pengembangan & gotcha kode
```

## 🔌 Backend (ringkas)

Semua endpoint mewajibkan `Authorization: Bearer <Google idToken | session token>` — kecuali `/api/health`.

| Method | Endpoint | Fungsi |
|---|---|---|
| GET | `/api/health` | Status server (publik) |
| GET | `/api/categories` | Daftar kategori belajar |
| GET | `/api/vocab?category=` | Kosakata per kategori |
| GET | `/api/videos?category=&type=` | Video per kategori & tipe |
| POST | `/api/me/profile` | Profil user — menerbitkan session token (web) |
| GET | `/api/me/progress?categories=` | Stats, jadwal SRS, video ditonton |
| POST | `/api/me/sync` | Sinkronisasi *all-or-nothing* |

Referensi lengkap: [`backend/README.md`](backend/README.md).

## 🗺️ Roadmap

- [ ] Cache konten (kata & video) untuk akses offline penuh
- [ ] Indikator *lanjut menonton* lintas perangkat
- [ ] Ikon & layar splash kustom
- [ ] Peringatan keamanan token pada konfigurasi

## 📚 Dokumen

| Dokumen | Isi |
|---|---|
| [`docs/PRODUCT_DESIGN.md`](docs/PRODUCT_DESIGN.md) | Alur produk, fitur, bentuk data, desain UI |
| [`AGENTS.md`](AGENTS.md) | Aturan pengembangan, gotcha, kontrak klien–server |
| [`backend/README.md`](backend/README.md) | Referensi API & environment backend |
