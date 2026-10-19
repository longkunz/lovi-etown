import { Controller, Get, Req, Inject, Optional } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import pg from 'pg';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
import { DATABASE_POOL } from '../database/pool.js';
import { ApiError } from '../http/api-error.js';
import { SetMetadata } from '@nestjs/common';
import { IS_PUBLIC_KEY } from '../http/api-key.guard.js';

export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

@Controller('health')
export class HealthController {
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Optional() @Inject(DATABASE_POOL) private readonly pool?: pg.Pool,
  ) {}

  @Get('live')
  @Public()
  live(@Req() request: FastifyRequest) {
    const requestId = (request as any).requestId;
    return {
      data: { status: 'live' },
      meta: {
        requestId,
        dataMode: this.config.cameraProviderMode,
      },
    };
  }

  @Get('ready')
  @Public()
  async ready(@Req() request: FastifyRequest) {
    const requestId = (request as any).requestId;
    if (this.pool) {
      try {
        await this.pool.query('SELECT 1');
      } catch (err) {
        throw new ApiError('SERVICE_UNAVAILABLE', 503, true, 'Database not ready');
      }
    }
    return {
      data: { status: 'ready', database: 'ready' },
      meta: {
        requestId,
        dataMode: this.config.cameraProviderMode,
      },
    };
  }
}
