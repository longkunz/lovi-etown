import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import pg from 'pg';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export interface MigrateOptions {
  pool: pg.Pool;
  schema?: string;
}

export async function runMigrations(options: MigrateOptions): Promise<string[]> {
  const { pool, schema } = options;
  let migrationsDir = path.resolve(process.cwd(), 'migrations');
  if (!fs.existsSync(migrationsDir)) {
    migrationsDir = path.resolve(__dirname, '..', '..', 'migrations');
    if (!fs.existsSync(migrationsDir)) {
      migrationsDir = path.resolve(__dirname, '..', '..', '..', 'migrations');
    }
  }

  if (!fs.existsSync(migrationsDir)) {
    throw new Error(`Migrations directory not found at: ${migrationsDir}`);
  }

  const migrationFiles = fs
    .readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  const client = await pool.connect();
  const appliedMigrations: string[] = [];

  try {
    await client.query('BEGIN');

    // Acquire transaction-level advisory lock (namespace 17001402)
    await client.query('SELECT pg_advisory_xact_lock(17001402)');

    if (schema) {
      await client.query(`SET LOCAL search_path TO "${schema}", public`);
    }

    // Ensure schema_migrations table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        version VARCHAR(64) UNIQUE NOT NULL,
        checksum VARCHAR(64) NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    // Fetch applied migrations
    const res = await client.query('SELECT version, checksum FROM schema_migrations ORDER BY id ASC');
    const appliedMap = new Map<string, string>();
    for (const row of res.rows) {
      appliedMap.set(row.version, row.checksum);
    }

    for (const file of migrationFiles) {
      const fullPath = path.join(migrationsDir, file);
      const content = fs.readFileSync(fullPath, 'utf8');
      const checksum = crypto.createHash('sha256').update(content).digest('hex');

      if (appliedMap.has(file)) {
        const recordedChecksum = appliedMap.get(file);
        if (recordedChecksum !== checksum) {
          throw new Error(
            `Migration checksum mismatch for ${file}. Recorded: ${recordedChecksum}, Actual: ${checksum}`
          );
        }
        continue;
      }

      // Execute migration
      await client.query(content);
      await client.query(
        'INSERT INTO schema_migrations (version, checksum) VALUES ($1, $2)',
        [file, checksum]
      );
      appliedMigrations.push(file);
    }

    await client.query('COMMIT');
    return appliedMigrations;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
