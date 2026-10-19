import dotenv from 'dotenv';
import { loadConfig } from '../config/config.js';
import { createDatabasePool } from '../database/pool.js';
import { runMigrations } from '../database/migrate.js';

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
    console.log('Running database migrations...');
    const applied = await runMigrations({ pool });
    if (applied.length === 0) {
      console.log('No new migrations to apply.');
    } else {
      console.log(`Applied ${applied.length} migration(s):`, applied);
    }
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
