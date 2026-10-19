import { Controller, Post, Body, UseGuards, Req, Inject, HttpCode } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { ApiKeyGuard } from '../http/api-key.guard.js';
import { AdminOnly } from '../http/admin-only.decorator.js';
import { SyncService } from './sync.service.js';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
import { ApiError } from '../http/api-error.js';
import { Bbox } from '../catalog/catalog.types.js';

export function validateBbox(bbox: any): Bbox {
  if (!Array.isArray(bbox) || bbox.length !== 4) {
    throw new ApiError('INVALID_INPUT', 400, false, 'bbox must be an array of 4 numbers [west, south, east, north]');
  }
  const [west, south, east, north] = bbox;
  if (
    typeof west !== 'number' ||
    typeof south !== 'number' ||
    typeof east !== 'number' ||
    typeof north !== 'number' ||
    !isFinite(west) ||
    !isFinite(south) ||
    !isFinite(east) ||
    !isFinite(north)
  ) {
    throw new ApiError('INVALID_INPUT', 400, false, 'bbox coordinates must be finite numbers');
  }

  if (west >= east || south >= north) {
    throw new ApiError('INVALID_INPUT', 400, false, 'Invalid bbox: west must be < east and south must be < north');
  }

  if (west < -180 || east > 180 || south < -90 || north > 90) {
    throw new ApiError('INVALID_INPUT', 400, false, 'bbox coordinates out of WGS84 range');
  }

  return [west, south, east, north];
}

@Controller('v1/admin/camera-providers/notis')
export class SyncController {
  constructor(
    private readonly syncService: SyncService,
    @Inject(APP_CONFIG) private readonly config: AppConfig
  ) {}

  @Post('sync')
  @HttpCode(200)
  @UseGuards(ApiKeyGuard)
  @AdminOnly()

  async sync(@Body() body: any, @Req() req: FastifyRequest) {
    if (!body || typeof body !== 'object') {
      throw new ApiError('INVALID_INPUT', 400, false, 'Body must be a valid JSON object');
    }

    const provinceId = body.provinceId || 'tp_hcm';
    if (provinceId !== 'tp_hcm') {
      throw new ApiError('UNSUPPORTED_PROVINCE', 400, false, 'Province not supported, only tp_hcm is allowed');
    }

    const bbox = validateBbox(body.bbox);
    const result = await this.syncService.sync({
      provinceId,
      bbox,
    });

    const requestId = (req as any).requestId;
    return {
      status: 'success',
      ...result,
      data: result,
      meta: {
        requestId,
        dataMode: this.config.cameraProviderMode,
      },
    };
  }
}

