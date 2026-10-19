import { Module } from '@nestjs/common';
import { SyncService } from './sync.service.js';
import { SyncController } from './sync.controller.js';
import { CatalogModule } from '../catalog/catalog.module.js';
import { ProvidersModule } from '../providers/providers.module.js';
import { DatabaseModule } from '../database/database.module.js';

@Module({
  imports: [CatalogModule, ProvidersModule, DatabaseModule],
  controllers: [SyncController],
  providers: [SyncService],
  exports: [SyncService],
})
export class SyncModule {}
