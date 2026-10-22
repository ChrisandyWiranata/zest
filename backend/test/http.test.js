import assert from 'node:assert/strict';
import { test } from 'node:test';

import { publicErrorMessage } from '../lib/http.js';

function errorWith(status, message) {
  const error = new Error(message);
  if (status !== undefined) error.status = status;
  return error;
}

test('pesan 4xx dipertahankan (kontrak ApiException Flutter)', () => {
  assert.equal(publicErrorMessage(errorWith(400, 'Terlalu banyak kategori')), 'Terlalu banyak kategori');
  assert.equal(publicErrorMessage(errorWith(401, 'idToken ditolak: nah')), 'idToken ditolak: nah');
  assert.equal(publicErrorMessage(errorWith(413, 'Payload terlalu besar.')), 'Payload terlalu besar.');
});

test('pesan 5xx selalu generik, detail internal tidak bocor', () => {
  assert.equal(
    publicErrorMessage(errorWith(500, 'libsql: http://user:pass@turso.io/db fail')),
    'Terjadi kesalahan di server.',
  );
  assert.equal(publicErrorMessage(new Error('SELECT * FROM users')), 'Terjadi kesalahan di server.');
  assert.equal(publicErrorMessage(undefined), 'Terjadi kesalahan di server.');
});

test('error tanpa status → 500 generik; 4xx tanpa pesan → generik', () => {
  assert.equal(publicErrorMessage(new Error('tanpa status')), 'Terjadi kesalahan di server.');
  assert.equal(publicErrorMessage(errorWith(400, '  ')), 'Terjadi kesalahan di server.');
});
