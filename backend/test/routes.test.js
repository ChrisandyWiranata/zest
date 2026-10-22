import assert from 'node:assert/strict';
import { test } from 'node:test';

import { isContentPath, needsAuth } from '../lib/routes.js';

test('isContentPath hanya katalog konten', () => {
  assert.equal(isContentPath('/api/categories'), true);
  assert.equal(isContentPath('/api/vocab'), true);
  assert.equal(isContentPath('/api/videos'), true);
  assert.equal(isContentPath('/api/health'), false);
  assert.equal(isContentPath('/api/me/progress'), false);
  assert.equal(isContentPath('/api/tidak-ada'), false);
});

test('needsAuth mencakup konten + /api/me/*, health publik', () => {
  assert.equal(needsAuth('/api/categories'), true);
  assert.equal(needsAuth('/api/vocab'), true);
  assert.equal(needsAuth('/api/videos'), true);
  assert.equal(needsAuth('/api/me/profile'), true);
  assert.equal(needsAuth('/api/me/progress'), true);
  assert.equal(needsAuth('/api/health'), false);
  assert.equal(needsAuth('/api/tidak-ada'), false);
});

test('path mirip tapi bukan route konten tidak dianggap terlindungi', () => {
  assert.equal(needsAuth('/api/categories/../me/progress'), false);
  assert.equal(needsAuth('/api/categoriesx'), false);
});
