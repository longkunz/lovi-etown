import { Injectable, Inject } from '@nestjs/common';
import crypto from 'node:crypto';
import { CATALOG_REPOSITORY, CatalogRepository } from '../catalog/catalog.repository.js';
import { CAMERA_PROVIDER, CameraProvider } from '../providers/camera-provider.js';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';
import { CLOCK, Clock } from '../http/request-context.js';
import { BoundedCache, CachedSnapshot } from './bounded-cache.js';
import { FetchPool } from './fetch-pool.js';
import { ApiError } from '../http/api-error.js';

export interface SnapshotResult {
  notModified: boolean;
  etag: string;
  bytes?: Buffer;
  mime?: string;
  fetchedAt: Date;
  dataMode: string;
}

interface InFlightRequest {
  promise: Promise<CachedSnapshot>;
  controller: AbortController;
  subscribers: number;
}

@Injectable()
export class SnapshotService {
  private readonly cache: BoundedCache;
  private readonly pool: FetchPool;
  private readonly inFlight = new Map<string, InFlightRequest>();

  constructor(
    @Inject(CATALOG_REPOSITORY) private readonly repository: CatalogRepository,
    @Inject(CAMERA_PROVIDER) private readonly provider: CameraProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {
    this.cache = new BoundedCache({
      maxSizeBytes: config.snapshotCacheMaxBytes,
      maxItemBytes: config.snapshotMaxBytes,
      ttlMs: config.snapshotTtlMs,
      clock,
    });
    this.pool = new FetchPool({
      maxActive: config.maxConcurrentUpstreamFetches,
      maxQueued: config.maxQueuedUpstreamFetches,
    });
  }

  async getSnapshot(
    cameraId: string,
    ifNoneMatch?: string,
    clientSignal?: AbortSignal,
  ): Promise<SnapshotResult> {
    // 1. Check cache first
    const cached = this.cache.get(cameraId);
    if (cached) {
      if (ifNoneMatch && ifNoneMatch === cached.etag) {
        return {
          notModified: true,
          etag: cached.etag,
          fetchedAt: cached.fetchedAt,
          dataMode: this.config.cameraProviderMode,
        };
      }
      return {
        notModified: false,
        etag: cached.etag,
        bytes: cached.bytes,
        mime: cached.mime,
        fetchedAt: cached.fetchedAt,
        dataMode: this.config.cameraProviderMode,
      };
    }

    // 2. Camera existence & playback capability check
    const camera = await this.repository.find(cameraId);
    if (!camera) {
      throw new ApiError('CAMERA_NOT_FOUND', 404, false, 'Camera not found');
    }

    if (camera.sourceKind !== 'snapshot' || !camera.sourceRef) {
      throw new ApiError('PLAYBACK_UNSUPPORTED', 422, false, 'Camera does not support snapshot playback');
    }

    // 3. Coalesced fetch
    let inFlightReq = this.inFlight.get(cameraId);

    if (!inFlightReq) {
      const controller = new AbortController();
      const execute = async (): Promise<CachedSnapshot> => {
        const release = await this.pool.acquire(controller.signal);
        try {
          const snapshot = await this.provider.fetchSnapshot(camera.sourceRef, controller.signal);
          const fetchedAt = this.clock.nowDate();
          const hash = crypto.createHash('sha1').update(snapshot.bytes).digest('hex');
          const etag = `"${hash}"`;

          const cachedItem: CachedSnapshot = {
            bytes: snapshot.bytes,
            mime: snapshot.mime,
            etag,
            fetchedAt,
          };

          this.cache.set(cameraId, cachedItem);

          // Best-effort availability update
          this.repository.updateAvailability(cameraId, 'online', fetchedAt).catch(() => {});

          return cachedItem;
        } finally {
          release();
        }
      };

      const promise = execute().finally(() => {
        this.inFlight.delete(cameraId);
      });

      inFlightReq = {
        promise,
        controller,
        subscribers: 0,
      };
      this.inFlight.set(cameraId, inFlightReq);
    }

    inFlightReq.subscribers++;

    // Safe cancellation handling
    let clientAborted = false;
    const currentInFlight = inFlightReq;

    if (clientSignal) {
      if (clientSignal.aborted) {
        currentInFlight.subscribers--;
        if (currentInFlight.subscribers <= 0) {
          currentInFlight.controller.abort();
          this.inFlight.delete(cameraId);
        }
        const err = new Error('The operation was aborted');
        err.name = 'AbortError';
        throw err;
      }

      const onAbort = () => {
        clientAborted = true;
        currentInFlight.subscribers--;
        if (currentInFlight.subscribers <= 0) {
          currentInFlight.controller.abort();
          this.inFlight.delete(cameraId);
        }
      };

      clientSignal.addEventListener('abort', onAbort, { once: true });
    }

    try {
      const result = await currentInFlight.promise;

      if (clientAborted || clientSignal?.aborted) {
        const err = new Error('The operation was aborted');
        err.name = 'AbortError';
        throw err;
      }

      if (ifNoneMatch && ifNoneMatch === result.etag) {
        return {
          notModified: true,
          etag: result.etag,
          fetchedAt: result.fetchedAt,
          dataMode: this.config.cameraProviderMode,
        };
      }

      return {
        notModified: false,
        etag: result.etag,
        bytes: result.bytes,
        mime: result.mime,
        fetchedAt: result.fetchedAt,
        dataMode: this.config.cameraProviderMode,
      };
    } finally {
      if (!clientAborted) {
        currentInFlight.subscribers--;
      }
    }
  }
}
