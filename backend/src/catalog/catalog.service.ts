import { Injectable, Inject } from '@nestjs/common';
import { CATALOG_REPOSITORY, CatalogRepository } from './catalog.repository.js';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
import { CatalogQuery } from './catalog.types.js';
import { CameraDto, PlaybackDto, toCameraDto } from './dto/camera.dto.js';
import { ApiError } from '../http/api-error.js';

@Injectable()
export class CatalogService {
  constructor(
    @Inject(CATALOG_REPOSITORY) private readonly catalogRepo: CatalogRepository,
    @Inject(APP_CONFIG) private readonly config: AppConfig
  ) {}

  async list(query: CatalogQuery) {
    const result = await this.catalogRepo.list(query);
    return {
      items: result.items.map(toCameraDto),
      page: {
        limit: query.limit,
        offset: query.offset,
        total: result.total,
      },
      catalog: result.catalog,
    };
  }

  async detail(id: string): Promise<CameraDto> {
    const record = await this.catalogRepo.find(id);
    if (!record) {
      throw new ApiError('NOT_FOUND', 404, false, `Camera with id '${id}' not found`);
    }
    return toCameraDto(record);
  }

  async districts(provinceId: string) {
    return this.catalogRepo.districts(provinceId);
  }

  async playback(id: string): Promise<PlaybackDto> {
    const record = await this.catalogRepo.find(id);
    if (!record) {
      throw new ApiError('NOT_FOUND', 404, false, `Camera with id '${id}' not found`);
    }

    if (!record.capabilities.snapshot) {
      throw new ApiError('PLAYBACK_UNSUPPORTED', 422, false, 'Camera playback is unsupported in A1');
    }

    return {
      cameraId: record.id,
      kind: 'snapshot',
      snapshotEndpoint: `/v1/cameras/${record.id}/snapshot`,
      refreshIntervalMs: this.config.defaultRefreshIntervalMs,
      capturedAt: null,
    };
  }

  async related(id: string, limit: number) {
    const record = await this.catalogRepo.find(id);
    if (!record) {
      throw new ApiError('NOT_FOUND', 404, false, `Camera with id '${id}' not found`);
    }

    const result = await this.catalogRepo.related(record, limit);
    return {
      items: result.items.map(toCameraDto),
      reason: result.reason,
    };
  }
}
