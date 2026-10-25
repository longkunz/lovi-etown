import { it } from 'node:test';
import assert from 'node:assert/strict';
import { toCatalogState } from '../../src/catalog/catalog-metadata.js';
it('preserves list metadata defaults, nullable dates, coverage and strict staleness threshold', () => {
  assert.deepEqual(toCatalogState(undefined, 1000, 100), {
    version: '0',
    fetchedAt: null,
    isStale: false,
    coverage: 'unknown',
    syncState: 'never_synced',
  });
  const row = { version: 2n, fetched_at: new Date(1000), coverage: 'partial' };
  assert.equal(toCatalogState(row, 1100, 100).isStale, false);
  assert.equal(toCatalogState(row, 1101, 100).isStale, true);
  assert.deepEqual(
    toCatalogState({ ...row, fetched_at: null, coverage: null }, 1101, 100),
    {
      version: '2',
      fetchedAt: null,
      isStale: false,
      coverage: 'unknown',
      syncState: 'synced',
    }
  );
});
