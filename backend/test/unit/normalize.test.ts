import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeText } from '../../src/catalog/normalize.js';

describe('Text Normalization (Unit)', () => {
  it('converts uppercase and trims surrounding whitespace', () => {
    assert.equal(normalizeText('   Quận 1   '), 'quan 1');
  });

  it('converts Vietnamese "đ" and "Đ" to "d"', () => {
    assert.equal(normalizeText('Đường Nguyễn Huệ'), 'duong nguyen hue');
    assert.equal(normalizeText('đoạn đường đỗ'), 'doan duong do');
  });

  it('normalizes composed and decomposed accents identically', () => {
    // Composed: \u00E9 (é)
    const composed = 'Đường Lê Lợi';
    // Decomposed: e + \u0301
    const decomposed = 'Đ\u01B0\u01A1\u0300ng Le\u0301 L\u01A1\u0323i';
    assert.equal(normalizeText(composed), normalizeText(decomposed));
    assert.equal(normalizeText(composed), 'duong le loi');
  });

  it('handles null, undefined and empty inputs cleanly', () => {
    assert.equal(normalizeText(null as any), '');
    assert.equal(normalizeText(undefined as any), '');
    assert.equal(normalizeText(''), '');
    assert.equal(normalizeText('   '), '');
  });

  it('preserves word boundaries and alphanumeric characters', () => {
    assert.equal(normalizeText('Camera 04 - Q. Bình Thạnh'), 'camera 04 - q. binh thanh');
  });
});
