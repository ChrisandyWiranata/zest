import { listCategories, listVideos, listWords } from '../lib/turso.js';
import { sendError, sendJson } from '../lib/http.js';

export async function handleContent(pathname, searchParams, res) {
  if (pathname === '/api/categories') {
    const rows = await listCategories();
    return sendJson(res, 200, { categories: rows });
  }

  if (pathname === '/api/vocab') {
    const category = searchParams.get('category');
    if (!category) return sendError(res, 400, 'Parameter category wajib diisi.');
    const rows = await listWords(category);
    return sendJson(res, 200, { words: rows });
  }

  if (pathname === '/api/videos') {
    const category = searchParams.get('category');
    if (!category) return sendError(res, 400, 'Parameter category wajib diisi.');
    const type = searchParams.get('type');
    const rows = await listVideos(category, type);
    return sendJson(res, 200, { videos: rows });
  }

  return sendError(res, 404, `Endpoint tidak dikenal: ${pathname}`);
}
