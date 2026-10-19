import pg from 'pg';
import crypto from 'node:crypto';
import { runMigrations } from '../../src/database/migrate.js';

export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ||
  'postgresql://postgres:postgres_test_password@127.0.0.1:5433/camera_catalog_test';

export function assertSafeTestDatabase(url: string): void {
  const parsed = new URL(url);
  const dbName = parsed.pathname.replace(/^\//, '');
  if (!dbName.includes('test')) {
    throw new Error(`Refusing to run tests against non-test database: ${dbName}`);
  }
}

export interface TestSchemaContext {
  pool: pg.Pool;
  schema: string;
  cleanup: () => Promise<void>;
}

export async function createTestSchemaContext(): Promise<TestSchemaContext> {
  assertSafeTestDatabase(TEST_DATABASE_URL);

  const pool = new pg.Pool({
    connectionString: TEST_DATABASE_URL,
    max: 5,
  });

  const schema = `test_${crypto.randomBytes(6).toString('hex')}`;
  const client = await pool.connect();
  try {
    await client.query(`CREATE SCHEMA "${schema}"`);
  } finally {
    client.release();
  }

  // Run migrations in the new isolated schema
  await runMigrations({ pool, schema });

  const cleanup = async () => {
    try {
      const dropClient = await pool.connect();
      try {
        await dropClient.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
      } finally {
        dropClient.release();
      }
    } finally {
      await pool.end();
    }
  };

  return { pool, schema, cleanup };
}
