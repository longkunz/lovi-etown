import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createTestSchemaContext, TEST_DATABASE_URL } from '../helpers/test-database.js';
import { FakeClock } from '../helpers/clock.js';
import { PgCatalogRepository } from '../../src/catalog/catalog.repository.js';
import { SyncService } from '../../src/sync/sync.service.js';
import { CameraProvider, SnapshotBytes } from '../../src/providers/camera-provider.js';
import { Bbox, ProviderCamera } from '../../src/catalog/catalog.types.js';
import { createApp } from '../../src/create-app.js';
import { loadConfig } from '../../src/config/config.js';
import { ApiError } from '../../src/http/api-error.js';

class MockDelayedProvider extends CameraProvider {
  constructor(private readonly delayMs: number = 50) {
    super();
  }

  async fetchCatalog(bbox: Bbox, signal?: AbortSignal): Promise<ProviderCamera[]> {
    if (this.delayMs > 0) {
      await new Promise((r) => setTimeout(r, this.delayMs));
    }
    return [
      {
        provider: 'notis',
        providerCameraId: '507f1f77bcf86cd799439099',
        name: 'Camera Đồng Khởi',
        provinceId: 'tp_hcm',
        sourceKind: 'snapshot',
        sourceRef: '507f1f77bcf86cd799439099',
      },
    ];
  }

  async fetchSnapshot(sourceRef: string, signal?: AbortSignal): Promise<SnapshotBytes> {
    return { bytes: Buffer.from('fake'), mime: 'image/png' };
  }
}

describe('Catalog Synchronization & Admin Boundary (Integration)', () => {
  it('prevents concurrent sync executions using PG session advisory lock (409 SYNC_IN_PROGRESS)', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);
      const slowProvider = new MockDelayedProvider(100);
      const syncService = new SyncService(repo, slowProvider, pool, schema);

      // Trigger two concurrent sync calls
      const p1 = syncService.sync({
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
      });

      // Small tick to ensure p1 has acquired lock
      await new Promise((r) => setTimeout(r, 10));

      const p2 = syncService.sync({
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
      });

      const [res1, res2Result] = await Promise.allSettled([p1, p2]);

      assert.equal(res1.status, 'fulfilled');
      assert.equal(res2Result.status, 'rejected');
      if (res2Result.status === 'rejected') {
        const err = res2Result.reason as ApiError;
        assert.equal(err.code, 'SYNC_IN_PROGRESS');
        assert.equal(err.status, 409);
        assert.equal(err.retryable, true);
      }

      // Subsequent call after p1 completion succeeds cleanly
      const p3 = await syncService.sync({
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
      });
      assert.ok(p3.version);
    } finally {
      await cleanup();
    }
  });

  it('admin sync POST endpoint is protected by ADMIN_API_KEY and rejects reader key', async () => {
    const { schema, cleanup } = await createTestSchemaContext();
    try {
      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-backend-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-backend-admin-key-32charslong!!',
      });

      const app = await createApp({ config });
      try {
        const payload = {
          provinceId: 'tp_hcm',
          bbox: [106.69, 10.76, 106.71, 10.78],
        };

        // 1. Missing header -> 401
        const resMissing = await app.inject({
          method: 'POST',
          url: '/v1/admin/camera-providers/notis/sync',
          payload,
        });
        assert.equal(resMissing.statusCode, 401);

        // 2. Reader key -> 403
        const resReader = await app.inject({
          method: 'POST',
          url: '/v1/admin/camera-providers/notis/sync',
          headers: { 'x-api-key': config.backendApiKey },
          payload,
        });
        assert.equal(resReader.statusCode, 403);
        const jsonReader = JSON.parse(resReader.payload);
        assert.equal(jsonReader.error.code, 'FORBIDDEN');
      } finally {
        await app.close();
      }
    } finally {
      await cleanup();
    }
  });
});
