import dotenv from 'dotenv';
import { loadConfig } from '../config/config.js';
import { createDatabasePool } from '../database/pool.js';
import { PgCatalogRepository } from '../catalog/catalog.repository.js';
import { NotisProvider } from '../providers/notis.provider.js';
import { FixtureProvider } from '../providers/fixture.provider.js';
import { SyncService, coverageForBbox } from '../sync/sync.service.js';
import { validateBbox } from '../sync/sync.controller.js';
import { Bbox, HCMC_CITY_BBOX } from '../catalog/catalog.types.js';

dotenv.config();

async function main() {
  const config = loadConfig(process.env);

  // Parse --bbox argument. Default (T13/D5): the city-wide HCMC window;
  // an explicit narrower --bbox syncs a partial window and the catalog
  // coverage claim degrades accordingly (see coverageForBbox).
  let bbox: Bbox = HCMC_CITY_BBOX;
  for (const arg of process.argv.slice(2)) {
    if (arg.startsWith('--bbox=')) {
      const parts = arg
        .replace('--bbox=', '')
        .split(',')
        .map((s) => parseFloat(s.trim()));
      bbox = validateBbox(parts);
    }
  }

  const pool = createDatabasePool(config);
  try {
    const repo = new PgCatalogRepository(pool, undefined, undefined, config.catalogStaleAfterMs);
    const provider =
      config.cameraProviderMode === 'fixture'
        ? new FixtureProvider()
        : new NotisProvider({
            authToken: config.notisAuthToken,
            timeoutMs: config.upstreamTimeoutMs,
          });

    const syncService = new SyncService(repo, provider, pool);

    console.log(`Starting camera synchronization for mode=${config.cameraProviderMode}...`);
    const result = await syncService.sync({
      provinceId: 'tp_hcm',
      bbox,
      coverage: coverageForBbox(bbox),
    });

    console.log(
      `Sync completed successfully: received=${result.receivedCount}, upserted=${result.upsertedCount}, version=${result.version}, coverage=${result.coverage}`
    );
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error(`Sync failed: ${err.message}`);
  process.exit(1);
});
