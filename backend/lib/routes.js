/**
 * Daftar route yang butuh identitas user terverifikasi. Dipakai `api/index.js`
 * sebagai satu sumber kebenaran untuk gerbang auth (konten & /api/me/*),
 * supaya daftar endpoint tidak ditulis dua kali.
 */

const CONTENT_PATHS = new Set(['/api/categories', '/api/vocab', '/api/videos']);

/** `/api/categories|vocab|videos` — katalog, wajib login (bukan anonim). */
export function isContentPath(pathname) {
  return CONTENT_PATHS.has(pathname);
}

/** Route yang memerlukan `Authorization: Bearer <google idToken>` yang sah. */
export function needsAuth(pathname) {
  return isContentPath(pathname) || pathname.startsWith('/api/me/');
}
