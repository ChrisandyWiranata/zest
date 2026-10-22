#!/usr/bin/env bash
# Build web dan siapkan artefak untuk project Vercel frontend.
#
# Penting: project Vercel frontend memakai root `build/web` (terlihat dari
# build/web/.vercel/project.json), jadi vercel.json di ROOT repo tidak ikut
# ter-deploy — header CSP/keamanan harus ikut ke dalam artefak.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build web

cp vercel.json build/web/vercel.json

# Artefak build yang bukan bagian dari app — jangan sampai ter-serve publik.
rm -f build/web/.env.local

echo "OK: build/web siap — vercel.json tersalin, .env.local dibuang."
echo "Catatan: .vercel/ di dalam build/web dibutuhkan untuk link project; jangan dihapus."
