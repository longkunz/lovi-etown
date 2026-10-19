import { Module, Global } from '@nestjs/common';
import pg from 'pg';
import { CATALOG_REPOSITORY, PgCatalogRepository } from './catalog.repository.js';
import { CatalogService } from './catalog.service.js';
import { CatalogController } from './catalog.controller.js';
import { DATABASE_POOL } from '../database/pool.js';
import { CLOCK, Clock, SystemClock } from '../http/request-context.js';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';

@Global()
@Module({
  controllers: [CatalogController],
  providers: [
    {
      provide: CLOCK,
      useClass: SystemClock,
    },
    {
      provide: CATALOG_REPOSITORY,
      useFactory: (pool: pg.Pool, clock: Clock, config: AppConfig) => {
        return new PgCatalogRepository(pool, config.databaseSchema, clock, config.catalogStaleAfterMs);
      },
      inject: [DATABASE_POOL, CLOCK, APP_CONFIG],
    },
    CatalogService,
  ],
  exports: [CATALOG_REPOSITORY, CLOCK, CatalogService],
})
export class CatalogModule {}
