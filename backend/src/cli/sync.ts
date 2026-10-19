import dotenv from 'dotenv';
import { loadConfig } from '../config/config.js';
import { createDatabasePool } from '../database/pool.js';
import { PgCatalogRepository } from '../catalog/catalog.repository.js';
import { NotisProvider } from '../providers/notis.provider.js';
import { FixtureProvider } from '../providers/fixture.provider.js';
import { SyncService } from '../sync/sync.service.js';
import { validateBbox } from '../sync/sync.controller.js';
import { Bbox } from '../catalog/catalog.types.js';

dotenv.config();

async function main() {
  const config = loadConfig(process.env);

  // Parse --bbox argument
  let bbox: Bbox = [106.69, 10.76, 106.71, 10.78]; // default bounded TP.HCM observation window
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
