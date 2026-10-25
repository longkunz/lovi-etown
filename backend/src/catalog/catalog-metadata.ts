import { CatalogState } from './catalog.types.js';
export function toCatalogState(
  row: any,
  nowMs: number,
  staleAfterMs: number
): CatalogState {
  if (!row)
    return {
      version: '0',
      fetchedAt: null,
      isStale: false,
      coverage: 'unknown',
      syncState: 'never_synced',
    };
  const fetched = row.fetched_at ? new Date(row.fetched_at) : null;
  return {
    version: String(row.version),
    fetchedAt: fetched?.toISOString() ?? null,
    isStale: fetched ? nowMs - fetched.getTime() > staleAfterMs : false,
    coverage: row.coverage || 'unknown',
    syncState: 'synced',
  };
}
