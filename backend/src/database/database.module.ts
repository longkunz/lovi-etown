import { Module, Global, OnApplicationShutdown, Inject } from '@nestjs/common';
import pg from 'pg';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
import { DATABASE_POOL, createDatabasePool } from './pool.js';

@Global()
@Module({
  providers: [
    {
      provide: DATABASE_POOL,
      useFactory: (config: AppConfig): pg.Pool => createDatabasePool(config),
      inject: [APP_CONFIG],
    },
  ],
  exports: [DATABASE_POOL],
})
export class DatabaseModule implements OnApplicationShutdown {
  constructor(@Inject(DATABASE_POOL) private readonly pool: pg.Pool) {}

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end();
  }
}
