import { Injectable, CanActivate, ExecutionContext, Inject } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { FastifyRequest } from 'fastify';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
import { IS_ADMIN_ONLY_KEY } from './admin-only.decorator.js';
import { ApiError } from './api-error.js';

export const IS_PUBLIC_KEY = 'isPublic';

@Injectable()
export class ApiKeyGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest<FastifyRequest>();
    const apiKeyHeader = request.headers['x-api-key'];

    const apiKey = typeof apiKeyHeader === 'string' ? apiKeyHeader.trim() : undefined;

    if (!apiKey) {
      throw new ApiError('UNAUTHORIZED', 401, false, 'Missing or empty x-api-key header');
    }

    const isAdminOnly = this.reflector.getAllAndOverride<boolean>(IS_ADMIN_ONLY_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isAdminOnly) {
      if (apiKey === this.config.adminApiKey) {
        return true;
      }
      // Recognized reader credentials (current or rotation-window previous)
      // are authenticated but not authorized for admin routes.
      if (apiKey === this.config.backendApiKey || apiKey === this.config.backendApiKeyPrevious) {
        throw new ApiError('FORBIDDEN', 403, false, 'Admin privileges required');
      }
      throw new ApiError('UNAUTHORIZED', 401, false, 'Invalid API key');
    }

    // Reader route: current key, the previous key while the rotation window
    // is open (T06-D3), or the admin key.
    if (
      apiKey === this.config.backendApiKey ||
      apiKey === this.config.adminApiKey ||
      (this.config.backendApiKeyPrevious !== undefined &&
        apiKey === this.config.backendApiKeyPrevious)
    ) {
      return true;
    }

    throw new ApiError('UNAUTHORIZED', 401, false, 'Invalid API key');
  }
}
