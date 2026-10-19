import dotenv from 'dotenv';
import { loadConfig } from '../config/config.js';
import { createDatabasePool } from '../database/pool.js';
import { PgCatalogRepository } from '../catalog/catalog.repository.js';
import { FixtureProvider } from '../providers/fixture.provider.js';

dotenv.config();

async function main() {
  const env = {
    BACKEND_API_KEY: 'placeholder-reader-key-32charslong!!',
    ADMIN_API_KEY: 'placeholder-admin-key-32charslong!!',
    ...process.env,
  };
  const config = loadConfig(env);
  const pool = createDatabasePool(config);


  try {
    console.log('Seeding fixture catalog...');
    const provider = new FixtureProvider();
    const repo = new PgCatalogRepository(pool, undefined, undefined, config.catalogStaleAfterMs);
    const cameras = await provider.fetchCatalog([106.6, 10.7, 106.8, 10.9]);

    const result = await repo.commitImport({
      provider: 'fixture',
      provinceId: 'tp_hcm',
      bbox: [106.6, 10.7, 106.8, 10.9],
      cameras,
      fetchedAt: new Date(),
      coverage: 'verified',
    });

    console.log(`Seeded successfully: ${result.upsertedCount} cameras, version: ${result.version}`);
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Seed fixture failed:', err);
  process.exit(1);
});
