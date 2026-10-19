import { Controller, Get, Param, Query, Req, UseGuards, Inject } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { ApiKeyGuard } from '../http/api-key.guard.js';
import { CatalogService } from './catalog.service.js';
import { parseCatalogQuery, validateUuid, validateProvinceId, parseRelatedLimit } from './query-schema.js';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';

@Controller('v1')
@UseGuards(ApiKeyGuard)
export class CatalogController {
  constructor(
    private readonly catalogService: CatalogService,
    @Inject(APP_CONFIG) private readonly config: AppConfig
  ) {}

  @Get('cameras')
  async list(@Req() req: FastifyRequest) {
    const query = parseCatalogQuery((req.query as Record<string, any>) || {});
    const result = await this.catalogService.list(query);
    const requestId = (req as any).requestId;

    return {
      data: result.items,
      meta: {
        requestId,
        dataMode: this.config.cameraProviderMode,
        page: result.page,
        catalog: result.catalog,
      },
    };
  }

  @Get('camera-districts')
  async districts(@Query('provinceId') provinceIdParam: string, @Req() req: FastifyRequest) {
    const provinceId = validateProvinceId(provinceIdParam);
    const data = await this.catalogService.districts(provinceId);
    const requestId = (req as any).requestId;

    return {
      data,
      meta: {
        requestId,
        dataMode: this.config.cameraProviderMode,
      },
    };
  }

  @Get('cameras/:id')
  async detail(@Param('id') idParam: string, @Req() req: FastifyRequest) {
    const id = validateUuid(idParam, 'id');
    const data = await this.catalogService.detail(id);
    const requestId = (req as any).requestId;

    return {
      data,
      meta: {
        requestId,
        dataMode: this.config.cameraProviderMode,
      },
    };
  }

  @Get('cameras/:id/playback')
  async playback(@Param('id') idParam: string, @Req() req: FastifyRequest) {
    const id = validateUuid(idParam, 'id');
    const data = await this.catalogService.playback(id);
    const requestId = (req as any).requestId;

    return {
      data,
      meta: {
        requestId,
        dataMode: this.config.cameraProviderMode,
      },
    };
  }

  @Get('cameras/:id/related')
  async related(
    @Param('id') idParam: string,
    @Query('limit') limitParam: any,
    @Req() req: FastifyRequest
  ) {
    const id = validateUuid(idParam, 'id');
    const limit = parseRelatedLimit(limitParam);
    const result = await this.catalogService.related(id, limit);
    const requestId = (req as any).requestId;

    const meta: Record<string, any> = {
      requestId,
      dataMode: this.config.cameraProviderMode,
    };
    if (result.reason) {
      meta.reason = result.reason;
    }

    return {
      data: result.items,
      meta,
    };
  }
}
