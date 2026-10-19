import { Injectable, NestInterceptor, ExecutionContext, CallHandler, Inject } from '@nestjs/common';
import { Observable } from 'rxjs';
import { FastifyRequest } from 'fastify';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
import { ApiError } from './api-error.js';

interface RateLimitBucket {
  count: number;
  resetAt: number;
}

@Injectable()
export class RateLimitInterceptor implements NestInterceptor {
  private readonly buckets = new Map<string, RateLimitBucket>();
  private readonly maxBuckets = 10000;
  private readonly windowMs = 60000;

  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest<FastifyRequest>();
    const apiKey = (request.headers['x-api-key'] as string) || 'anon';
    const ip = request.ip || '127.0.0.1';
    const clientKey = `${apiKey}:${ip}`;

    const now = Date.now();
    this.cleanup(now);

    let bucket = this.buckets.get(clientKey);
    if (!bucket || bucket.resetAt <= now) {
      bucket = { count: 1, resetAt: now + this.windowMs };
      this.buckets.set(clientKey, bucket);
    } else {
      bucket.count += 1;
    }

    if (bucket.count > this.config.rateLimitMaxPerMinute) {
      throw new ApiError('RATE_LIMIT_EXCEEDED', 429, true, 'Rate limit exceeded');
    }

    return next.handle();
  }

  private cleanup(now: number): void {
    if (this.buckets.size < this.maxBuckets) return;

    for (const [key, bucket] of this.buckets.entries()) {
      if (bucket.resetAt <= now) {
        this.buckets.delete(key);
      }
    }

    // If still oversized, clear oldest
    if (this.buckets.size >= this.maxBuckets) {
      const keysToDelete = Array.from(this.buckets.keys()).slice(0, Math.floor(this.maxBuckets / 2));
      for (const k of keysToDelete) {
        this.buckets.delete(k);
      }
    }
  }
}
