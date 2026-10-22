import { createServer } from 'node:http';

import { handle } from '../api/index.js';

const port = Number(process.env.PORT ?? 3000);

const server = createServer((req, res) => {
  handle(req, res).catch((error) => {
    console.error('[zest-api]', error);
    if (!res.headersSent) {
      res.statusCode = 500;
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
    }
    res.end(JSON.stringify({ error: 'Terjadi kesalahan di server.' }));
  });
});

server.listen(port, () => {
  console.log(`zest-api berjalan di http://localhost:${port}`);
  console.log('CORS allowed origins:', process.env.ALLOWED_ORIGINS || '(kosong — semua origin ditolak)');
});
