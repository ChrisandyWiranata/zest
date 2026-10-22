# PRODUCT — Alur Aplikasi, Fitur, Data & Desain "zest"

> Dokumen ini menjelaskan **apa yang sedang dibangun** di aplikasi **zest**,
> bagaimana **alur penggunaannya**, **bentuk data** di belakangnya, dan
> **desain** yang dipakai. Ditulis untuk AI lain agar paham produk tanpa perlu
> membaca kode. Tidak membahas implementasi teknis, fungsi, atau pengujian.
>
> ~ Perlu versi yang membahas kode? Lihat `AGENTS.md` (gotcha & aturan kerja).

---

## 1. Tentang Zest

**zest** adalah aplikasi seluler untuk **belajar bahasa Jepang**, dirancang agar
konsisten dipakai tiap hari dalam sesi singkat. Dua pilar utama:

1. **Flashcard SRS (Spaced Repetition)** — kosakata dijadwalkan ulang secara
   otomatis. Kata yang sudah Anda jawab "hafal" muncul lagi nanti (jarak makin
   lama seiring makin terbiasa); yang belum hafal diulang di sesi yang sama.
2. **Video terstruktur** — pelajaran video per kategori, dibedakan menjadi
   **Bunpou (tata bahasa)** dan **Kosakata**, disusun per bab.

Sistem motivasi menyertai kedua pilar: **XP** (poin per jawaban benar), **level**
(naik tiap kelipatan poin), dan **streak harian** (hari beruntun belajar).

Posisi produk:

- Masuk memakai **akun Google**; tidak ada pendaftaran manual.
- Pengguna bisa **belajar tanpa internet aktif** karena progres tersimpan di
  perangkat, lalu **disinkronkan ke akun** — aman saat ganti/pindah perangkat.
- Bahasa antarmuka: **Indonesia** (dengan istilah Jepang sebagai konten belajar).

---

## 2. Apa yang Sedang Dibuat (Fitur & Status)

### 2.1 Sudah berjalan

**Masuk & akun**
- Login sekali lewat Google; sesi diingat (buka aplikasi → langsung di Beranda).
- Logout dengan konfirmasi, dari halaman Profil.

**Beranda (dashboard)**
- Sapaan disesuaikan nama user + ringkasan suasana hari ini.
- Kartu **XP & level**: total XP, level, progres menuju level berikutnya, streak.
- Kartu **"Flashcard hari ini"**: jumlah ulangan jatuh tempo + kata baru; tombol
  *Mulai* langsung membuka kategori yang paling perlu dikerjakan.
- **Statistik singkat**: XP hari ini, jumlah kata hafal, jumlah video ditonton.
- **Grid kategori**: tiap kategori (mis. N5, Hiragana) dengan jumlah kata,
  progres hafal, dan badge ulangan yang tertunda.
- Tarik-untuk-muat-ulang.

**Belajar kosakata (flashcard)**
- Daftar kata per kategori + **pencarian** (cari kata/bacaan/arti).
- Tombol **Mulai Flashcard** menampilkan label dinamis (mis. "Review 5 · Baru 3").
- Sesi flashcard: kartu yang **dibalik 3D**, sisi depan (kata + bacaan) → sisi
  belakang (arti + contoh kalimat), jawaban **"Sudah hafal"** / **"Belum hafal"**.
  - Jawaban benar → +XP, jawaban salah → kata diulang lagi di akhir sesi.
  - Kartu baru dibatasi per sesi; ulasan yang jatuh tempo diprioritaskan.
- **Audio pengucapan**: tombol speaker kecil di dekat bacaan, di kartu depan,
  kartu belakang, dan daftar kata. Satu ketukan → mengucapkan bacaan.
  - Suara **di-bundle ke dalam app** (MP3, ±10 MB) → tersedia offline tanpa
    server apa pun; tombol disembunyikan untuk bacaan yang tidak ada audionya.
    Versi dev bisa memakai sintesis VOICEVOX langsung (`VOICEVOX_BASE_URL`).
- **Ringkasan sesi**: total kartu, jumlah benar, XP didapat, streak & level;
  **konfeti** + pesan khusus bila naik level.

**Belajar video**
- Playlist per kategori, dikelompokkan per bab, dengan **filter Gabung |
  Bunpou | Kosakata**.
- Pemutar video (lanjut otomatis dari posisi terakhir — indikator "Lanjut
  menonton" di daftar), judul & badge tipe, dan status **"Sudah ditonton"**:
  - otomatis ditandai saat video selesai, atau manual lewat toggle.

**Profil**
- Identitas Google (avatar/nama/email).
- **6 statistik**: XP total, level, streak, XP hari ini, kata hafal, video ditonton.
- **Status sinkronisasi** cloud + tombol "Sekarang" untuk menyinkronkan manual.
- Keluar akun (dengan dialog konfirmasi).

**Sinkronisasi (perilaku, bukan tombol)**
- Progres otomatis dikirim ke akun saat terjadi perubahan, saat masuk Profil,
  dan saat aplikasi dipindah ke latar belakang.

### 2.2 Rencana / belum dibuat (backlog)

- Cache & akses offline penuh untuk konten (kata/video) — saat ini memuat
  konten butuh koneksi.
- Keamanan token (nilai berjalan di konfigurasi aplikasi).
- Ikon & layar splash khusus (masih bawaan).
- Indikator "Lanjut menonton" lintas perangkat (posisi video kini lokal-only).

---

## 3. Alur Aplikasi (User Flow)

### 3.1 Pertama kali memakai

1. Buka aplikasi → **layar selamat datang** (logo, narasi, tombol "Masuk dengan Google").
2. Pilih akun Google → aplikasi menyiapkan akun baru (membuat data kosong di
   cloud) → masuk **Beranda**.
3. (Khusus pengguna lama yang datanya ada sebelum fitur akun) progres yang
   tersimpan otomatis dipindahkan ke akun pada login pertama.

### 3.2 Kembali memakai (sesi tersimpan)

1. Buka aplikasi → otomatis masuk langsung ke **Beranda** tanpa login ulang.
2. Beranda menampilkan kondisi terkini sesuai data terakhir.

### 3.3 Belajar flashcard

1. Beranda → ketuk kategori di grid (atau tombol *Mulai* pada "Flashcard hari ini").
2. Masuk halaman kategori (tab **Kosakata** & **Video**).
3. Ketuk **Mulai Flashcard** → sesi dimulai.
4. Lihat kata → **ketuk kartu untuk membalik** → baca arti & contoh.
5. Jawab **Sudah hafal** / **Belum hafal**.
   - Setiap jawaban: XP naik; kata yang belum hafal diputar lagi di akhir.
6. Sesi selesai → ringkasan (+XP, streak, level; konfeti saat naik level) →
   *Selesai* kembali ke kategori dengan status terbaru.

### 3.4 Menonton video

1. Kategori → tab **Video**.
2. Pilih mode: **Gabung** (semua), **Bunpou**, atau **Kosakata**.
3. Ketuk video di bawah bab → pemutar terbuka.
   - Video yang belum tuntas menampilkan tanda "Lanjut menonton"; dibuka → lanjut
     dari posisi terakhir.
   - Selesai ditonton → otomatis ditandai ✓ ; bisa juga ditandai manual.
4. Kembali → daftar diperbarui.

### 3.5 Profil & keluar

1. Tab **Profil** di bawah → identitas, statistik, status sinkron.
2. Sinkron manual: ketuk "Sekarang".
3. **Keluar** → dialog konfirmasi → kembali ke layar masuk. Progres tetap aman
   di akun (untuk dipulihkan saat masuk lagi, termasuk di perangkat lain).

---

## 4. Bentuk Data (Database)

Satu basis data Turso digunakan. Ada dua kelompok tabel:

### 4.1 Konten (data yang dipelajari — diisi via admin/seed, bukan dari aplikasi)

| Tabel | Isi | Kolom penting |
|---|---|---|
| `categories` | Kategori belajar (mis. N5, Hiragana, Bunpou) | kode kategori (slug), judul, level, deskripsi, urutan |
| `vocabularies` | Kata kosakata | kata, bacaan, arti, contoh + terjemahan, kategori, waktu |
| `videos` | Pelajaran video | kategori, bab, tipe (`grammar` / `kosakata`), judul, URL video, urutan |

### 4.2 Progres pengguna (di-shard per akun)

Setiap baris selalu menyertakan id akun (Google) sehingga data antar-user
terisolasi.

| Tabel | Isi |
|---|---|
| `users` | Profil login: id akun, email, nama tampilan, avatar, waktu dibuat & terakhir aktif |
| `user_stats` | Ringkasan motivasi: XP total, streak, tanda hari, XP hari ini |
| `user_srs_states` | Status tiap kartu per kategori: jumlah ulangan benar, jarak ulang (hari), kemudahan, tanggal jatuh tempo |
| `user_watched` | Video yang sudah ditonton (id akun, kategori, id video) |
| `user_meta` | Metadata akun: versi data, waktu sinkronisasi terakhir |

**Prinsip penting:**
- Waktu disimpan sebagai **detik epoch**, dan "hari" dihitung per zona UTC.
- Tabel progres memakai **upsert** (sisip-atau-perbarui) — tidak ada duplikat.
- Data konten adalah referensi; progres menautkannya via id/kunci stabil agar
  perubahan teks tidak menghapus progres.

---

## 5. Desain

### 5.1 Filosofi

**Dark-minimalis.** Satu warna aksen hangat (merah torii) di atas nuansa abu
kehitaman yang tenang; hijau/merah dipakai **semantik** (hafal vs belum), bukan
dekorasi. Tidak ada gradien ramai atau bayangan berat — kesan bersih, fokus ke
konten, nyaman dipakai malam hari.

### 5.2 Palet warna

| Token | Warna | Pemakaian |
|---|---|---|
| Level latar | `#0A0A0B` | latar paling gelap |
| Level latar sekunder | `#121214` | bidang/groove di dalam elemen |
| Permukaan kartu | `#1B1B1E` | kartu, input, chip |
| Garis | `#2C2C30` | border, pemisah |
| **Aksten utama** | `#E0574A` | tombol utama, ikon aktif, penekanan |
| Aksten lembut | `#F08A7A` | bacaan furigana, aksen kecil |
| Teks utama | `#F1F1EF` | konten utama |
| Teks sekunder | `#A6A6AC` | label, keterangan |
| Teks hint | `#86868E` | petunjuk/placeholder — **dinaikkan kontrasnya agar mudah dibaca (WCAG AA)** |
| Hafal/sukses | `#6FCF97` | benar, hafal, selesai ditonton |
| Belum/gagal | `#EB8D8B` | salah, belum, destruktif, error |

### 5.3 Tipografi & gaya teks

- Judul & angka memakai ketebalan **tebal** (800–900) dengan spasi antar-huruf;
- teks kecil/label memakai tebal sedang dan warna sekunder;
- skala teks konvensional (body, titleLarge, headline, dsb.);
- hierarki dijaga via **berat + warna** (bukan hanya ukuran): judul putih terang,
  keterangan abu, hint abu paling redup.

### 5.4 Pola komponen

- **Kartu**: permukaan `#1B1B1E`, sudut membulat (16–18), garis 1px — hampir
  semua panel memakai pola ini.
- **Pill/chip**: segmen kecil membulat (ikon 14 + label tebal) untuk statistik &
  tag fitur.
- **Badge**: pill kecil berwarna aksen untuk "N ulangan tertunda".
- **Tombol utama (CTA)**: penuh, aksen torii, sudut membulat, tinggi konsisten
  — semua tindakan primer ("Mulai", "Selesai", "Sekarang") memakainya.
- **Tombol speaker (TTS)**: lingkaran kecil (34px) berikon `volume_up` di dekat
  bacaan; memutar pengucapan saat diketuk, spinner singkat saat memuat. Hanya
  muncul bila audio bacaan tersebut tersedia (di-bundle di app).
- **Skeleton saat memuat**: blok rata (tanpa kedip), aman & kalem.

### 5.5 Gerakan (motion)

Vokabular animasi yang konsisten & lembut:

- **Count-up** angka (XP, statistik) — naik halus saat nilai berubah.
- **Press-scale** — elemen interaktif mengecil sedikit saat disentuh.
- **Flip 3D** — kartu flashcard dibalik dengan efek rotasi.
- **Stagger muncul** — kartu-kartu di grid muncul berurutan dengan sedikit loncat.
- **Transisi layar** — fade + slide-up halus antar-halaman.
- **Konfeti** — ledakan sekali saat momen perayaan (naik level).
- **Partikel latar (ambient)** — bokeh redup melayang di layar bertema.

Prinsip: **setiap animasi selesai dengan sendirinya** (tidak ada yang berputar
terus-terusan), dan **mode "kurangi gerakan" perangkat dihormati** (partikel &
konfeti berhenti, animasi disederhanakan).

### 5.6 Layout & aksesibilitas

- Mobile-first: konten satu kolom, navigasi bawah 2 tab (**Beranda | Profil**).
- Layar lebar (web/desktop): konten **dibatasi satu kolom** (lebar maks ~1000px)
  agar tidak mengambang.
- Kontras teks dijaga lolos standar aksesibilitas (khususnya teks tersier).
- Haptic ringan pada jawaban flashcard (benar/salah) sebagai umpan balik.

### 5.7 Keputusan desain yang disengaja

1. **Skeleton statis** tanpa efek shimmer → penampilan tenang & deterministik.
2. **Satu aksen** → semua CTA konsisten, status memakai warna semantik sendiri.
3. **Logout butuh konfirmasi** → dialog, mencegah kehilangan sesi tak sengaja.
4. **Ulangan yang gagal diulang di sesi yang sama** → pembelajaran lebih efektif
   (hanya sekali per sesi agar tidak berulang-ulang).
5. **Ring XP digambar sebagai cincin progres level** → informasi "sisa XP menuju
   level berikutnya" langsung terbaca.

---

## 6. Indeks Layar

| Layar | Isi singkat |
|---|---|
| Selamat datang | Logo, narasi, tombol Masuk dengan Google, pill fitur |
| Beranda | Sapaan, XP/level, flashcard hari ini, statistik, grid kategori |
| Detail kategori | Tab Kosakata (daftar + cari + Mulai Flashcard) & Video (playlist per bab + filter) |
| Sesi flashcard | Kartu balik, jawaban hafal/belum, penghitung & XP sesi |
| Ringkasan sesi | Hasil, XP, streak/level, konfeti, Selesai |
| Pemutar video | Video + resume, judul/badge tipe, toggle "Sudah ditonton" |
| Profil | Identitas, 6 statistik, status & tombol sinkron, Akun Google, Keluar |