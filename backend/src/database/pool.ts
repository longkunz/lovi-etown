import pg from 'pg';
import { AppConfig } from '../config/config.js';

export const DATABASE_POOL = 'DATABASE_POOL';

export function createDatabasePool(config: AppConfig): pg.Pool {
  return new pg.Pool({
    connectionString: config.databaseUrl,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
  });
}
