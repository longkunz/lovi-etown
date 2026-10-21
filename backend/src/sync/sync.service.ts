import { Injectable, Inject, Optional } from '@nestjs/common';
import pg from 'pg';
import { CATALOG_REPOSITORY, CatalogRepository } from '../catalog/catalog.repository.js';
import { CAMERA_PROVIDER, CameraProvider } from '../providers/camera-provider.js';
import { DATABASE_POOL } from '../database/pool.js';
import { Bbox, HCMC_CITY_BBOX, ImportResult } from '../catalog/catalog.types.js';
import { ApiError } from '../http/api-error.js';

export const SYNC_ADVISORY_LOCK_ID = 17001401;

/**
 * Coverage claim for a sync (T13): a sync whose window fully contains the
 * city-wide HCMC window supports the `verified` coverage claim; anything
 * narrower only supports `partial`. Kept pure/unit-testable on purpose.
 */
export function coverageForBbox(bbox: Bbox): 'partial' | 'verified' {
  const [west, south, east, north] = bbox;
  const [cityWest, citySouth, cityEast, cityNorth] = HCMC_CITY_BBOX;
  return west <= cityWest && south <= citySouth && east >= cityEast && north >= cityNorth
    ? 'verified'
    : 'partial';
}

@Injectable()
export class SyncService {
  constructor(
    @Inject(CATALOG_REPOSITORY) private readonly catalogRepo: CatalogRepository,
    @Inject(CAMERA_PROVIDER) private readonly provider: CameraProvider,
    @Inject(DATABASE_POOL) private readonly pool: pg.Pool,
    @Optional() private readonly schemaName?: string
  ) {}

  async sync(input: {
    provinceId: string;
    bbox: Bbox;
    coverage?: 'partial' | 'verified';
    signal?: AbortSignal;
  }): Promise<ImportResult> {
    const client = await this.pool.connect();
    if (this.schemaName) {
      await client.query(`SET search_path TO "${this.schemaName}", public`);
    }

    let lockAcquired = false;
    try {
      const lockRes = await client.query('SELECT pg_try_advisory_lock($1) as locked', [
        SYNC_ADVISORY_LOCK_ID,
      ]);
      lockAcquired = Boolean(lockRes.rows[0]?.locked);

      if (!lockAcquired) {
        throw new ApiError(
          'SYNC_IN_PROGRESS',
          409,
          true,
          'Catalog synchronization already in progress'
        );
      }

      const startedAt = new Date();
      try {
        const cameras = await this.provider.fetchCatalog(input.bbox, input.signal);
        const providerName = cameras.length > 0 ? cameras[0].provider : 'notis';

        const result = await this.catalogRepo.commitImport({
          provider: providerName,
          provinceId: input.provinceId,
          bbox: input.bbox,
          cameras,
          fetchedAt: startedAt,
          coverage: input.coverage ?? coverageForBbox(input.bbox),
        });

        return result;
      } catch (err: any) {
        // Record failure in catalog_imports outside rolled back transaction
        try {
          await client.query(
            `INSERT INTO catalog_imports (
               provider, province_id, bbox, outcome, started_at, finished_at, error_message
             ) VALUES ('notis', $1, $2, 'failure', $3, NOW(), $4)`,
            [
              input.provinceId,
              JSON.stringify(input.bbox),
              startedAt,
              err?.publicMessage || err?.message || 'Sync failed',
            ]
          );
        } catch {
          // ignore secondary logging error
        }
        throw err;
      }
    } finally {
      if (lockAcquired) {
        await client.query('SELECT pg_advisory_unlock($1)', [SYNC_ADVISORY_LOCK_ID]);
      }
      client.release();
    }
  }
}
