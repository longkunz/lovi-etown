import { mapCameraSchema } from './dto/map-camera.dto.js';
import { Controller, Get, Req, Inject } from '@nestjs/common';
import {
  ApiSecurity,
  ApiQuery,
  ApiOkResponse,
  ApiResponse,
} from '@nestjs/swagger';
import { FastifyRequest } from 'fastify';
import { MapCatalogService } from './map-catalog.service.js';
import { parseMapQuery } from './map-query-schema.js';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
@Controller('v1')
@ApiSecurity('ApiKeyAuth')
export class MapCatalogController {
  constructor(
    private readonly service: MapCatalogService,
    @Inject(APP_CONFIG) private readonly config: AppConfig
  ) {}
  @Get('map-cameras')
  @ApiQuery({ name: 'provinceId', required: true, enum: ['tp_hcm'] })
  @ApiQuery({
    name: 'bbox',
    required: false,
    description: 'west,south,east,north; mutually exclusive with nearby fields',
  })
  @ApiQuery({
    name: 'lat',
    required: false,
    type: Number,
    minimum: -90,
    maximum: 90,
  })
  @ApiQuery({
    name: 'lng',
    required: false,
    type: Number,
    minimum: -180,
    maximum: 180,
  })
  @ApiQuery({
    name: 'radiusMeters',
    required: false,
    type: Number,
    minimum: 100,
    maximum: 5000,
  })
  @ApiQuery({ name: 'district', required: false, type: String })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    minimum: 1,
    maximum: 200,
  })
  @ApiOkResponse({
    description:
      'Bounded map cameras; straight-line distance in meters for nearby, null for bbox. Catalog coverage may be incomplete.',
    schema: {
      type: 'object',
      required: ['data', 'meta'],
      properties: {
        data: {
          type: 'array',
          items: mapCameraSchema,
        },
        meta: {
          type: 'object',
          properties: {
            requestId: { type: 'string' },
            dataMode: { type: 'string' },
            result: {
              type: 'object',
              properties: {
                limit: { type: 'integer' },
                returned: { type: 'integer' },
                hasMore: { type: 'boolean' },
              },
            },
            catalog: {
              type: 'object',
              required: [
                'version',
                'fetchedAt',
                'isStale',
                'coverage',
                'syncState',
              ],
              properties: {
                version: { type: 'string' },
                fetchedAt: {
                  type: 'string',
                  format: 'date-time',
                  nullable: true,
                },
                isStale: { type: 'boolean' },
                coverage: {
                  type: 'string',
                  enum: ['unknown', 'partial', 'verified'],
                },
                syncState: { type: 'string', enum: ['never_synced', 'synced'] },
              },
            },
          },
        },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description: 'INVALID_INPUT or UNSUPPORTED_PROVINCE',
  })
  @ApiResponse({ status: 401, description: 'Missing or invalid API key' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded' })
  async query(@Req() request: FastifyRequest) {
    const query = parseMapQuery(
      (request.query ?? {}) as Record<string, unknown>
    );
    const result = await this.service.query(query);
    return {
      data: result.items,
      meta: {
        requestId: (request as any).requestId,
        dataMode: this.config.cameraProviderMode,
        result: result.result,
        catalog: result.catalog,
      },
    };
  }
}
