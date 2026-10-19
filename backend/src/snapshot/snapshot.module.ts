import { Module } from '@nestjs/common';
import { SnapshotController } from './snapshot.controller.js';
import { SnapshotService } from './snapshot.service.js';
import { CatalogModule } from '../catalog/catalog.module.js';
import { ProvidersModule } from '../providers/providers.module.js';

@Module({
  imports: [CatalogModule, ProvidersModule],
  controllers: [SnapshotController],
  providers: [SnapshotService],
  exports: [SnapshotService],
})
export class SnapshotModule {}
