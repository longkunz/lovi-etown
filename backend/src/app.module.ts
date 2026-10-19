import { Module, DynamicModule } from '@nestjs/common';
import { ConfigModule } from './config/config.module.js';
import { DatabaseModule } from './database/database.module.js';
import { CatalogModule } from './catalog/catalog.module.js';
import { ProvidersModule } from './providers/providers.module.js';
import { SyncModule } from './sync/sync.module.js';
import { HealthModule } from './health/health.module.js';
import { SnapshotModule } from './snapshot/snapshot.module.js';
import { CLOCK, SystemClock } from './http/request-context.js';
import { ApiKeyGuard } from './http/api-key.guard.js';
import { RateLimitInterceptor } from './http/rate-limit.js';
import { AppConfig, loadConfig } from './config/config.js';

export interface AppModuleOptions {
  config?: AppConfig;
  testingControllers?: any[];
}

@Module({})
export class AppModule {
  static forRoot(options?: AppModuleOptions): DynamicModule {
    const config = options?.config || loadConfig();
    return {
      module: AppModule,
      imports: [
        ConfigModule.forRoot(config),
        DatabaseModule,
        CatalogModule,
        ProvidersModule,
        SyncModule,
        HealthModule,
        SnapshotModule,
      ],
      controllers: options?.testingControllers || [],
      providers: [
        {
          provide: CLOCK,
          useClass: SystemClock,
        },
        ApiKeyGuard,
        RateLimitInterceptor,
      ],
      exports: [
        ConfigModule,
        DatabaseModule,
        CatalogModule,
        ProvidersModule,
        SyncModule,
        SnapshotModule,
        CLOCK,
        ApiKeyGuard,
        RateLimitInterceptor,
      ],
    };
  }
}

