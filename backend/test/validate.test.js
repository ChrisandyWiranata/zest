import assert from 'node:assert/strict';
import { test } from 'node:test';

import { LIMITS, ValidationError, parseCategories, validateSyncPayload } from '../lib/validate.js';

test('parseCategories: trim, buang kosong, dedupe', () => {
  assert.deepEqual(parseCategories(' n5 , n4 ,, n5 ,'), ['n5', 'n4']);
  assert.deepEqual(parseCategories(null), []);
  assert.deepEqual(parseCategories(''), []);
});

test('parseCategories: menolak lebih dari batas', () => {
  const tooMany = Array.from({ length: LIMITS.categoriesPerRequest + 1 }, (_, i) => `c${i}`).join(',');
  assert.throws(() => parseCategories(tooMany), (error) => {
    assert.ok(error instanceof ValidationError);
    assert.equal(error.status, 400);
    return true;
  });
  const boundary = Array.from({ length: LIMITS.categoriesPerRequest }, (_, i) => `c${i}`).join(',');
  assert.equal(parseCategories(boundary).length, LIMITS.categoriesPerRequest);
});

test('validateSyncPayload: body kosong → default aman', () => {
  assert.deepEqual(validateSyncPayload({}), { stats: null, srs: [], watched: [] });
  assert.deepEqual(validateSyncPayload(null), { stats: null, srs: [], watched: [] });
  assert.deepEqual(validateSyncPayload('bukan objek'), { stats: null, srs: [], watched: [] });
});

test('validateSyncPayload: payload sah diteruskan apa adanya', () => {
  const body = {
    stats: { total: 10, streak: 2, lastDay: 5, todayXp: 1, todayDay: 6 },
    srs: [{ category: 'n5', cards: [{ key: 'k1', n: 3, interval: 7, ease: 2.5, due: 1 }] }],
    watched: [{ category: 'n5', keys: ['v1', 'v2'] }],
  };
  assert.deepEqual(validateSyncPayload(body), body);
});

test('validateSyncPayload: stats null & field opsional yang hilang diizinkan', () => {
  const out = validateSyncPayload({ stats: null, srs: [{ category: 'n5', cards: [] }] });
  assert.equal(out.stats, null);
  assert.deepEqual(out.srs, [{ category: 'n5', cards: [] }]);
});

function expectValidation(body) {
  assert.throws(() => validateSyncPayload(body), (error) => {
    assert.ok(error instanceof ValidationError, `dapat ${error}`);
    assert.equal(error.status, 400);
    return true;
  });
}

test('validateSyncPayload: tipe salah ditolak 400, bukan lolos ke SQL', () => {
  expectValidation({ stats: { total: '10' } });
  expectValidation({ stats: [] });
  expectValidation({ srs: 'bukan-array' });
  expectValidation({ watched: 'bukan-array' });
  expectValidation({ srs: [{ category: 'n5', cards: [{ key: 'k', n: '3' }] }] });
  expectValidation({ srs: [{ category: 42 }] });
  expectValidation({ srs: [{ category: 'n5', cards: 'bukan' }] });
  expectValidation({ srs: [{ cards: [] }] });
  expectValidation({ watched: [{ category: 'n5', keys: [1] }] });
  expectValidation({ watched: [{ keys: ['a'] }] });
});

test('validateSyncPayload: key/kategori terlalu panjang ditolak', () => {
  const long = 'x'.repeat(LIMITS.idLength + 1);
  expectValidation({ srs: [{ category: long, cards: [] }] });
  expectValidation({ watched: [{ category: 'n5', keys: [long] }] });
  expectValidation({ srs: [{ category: 'n5', cards: [{ key: long }] }] });
  expectValidation({ srs: [{ category: 'n5', cards: [{ key: 'ok', due: long }] }] });
});

test('validateSyncPayload: total statement melebihi batas ditolak', () => {
  const cards = Array.from({ length: 1000 }, (_, i) => ({ key: `k${i}` }));
  const groups = Array.from({ length: LIMITS.syncStatements / 1000 + 1 }, () => ({
    category: 'n5',
    cards,
  }));
  expectValidation({ srs: groups });
});
