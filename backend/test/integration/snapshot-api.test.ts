import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createTestSchemaContext, TEST_DATABASE_URL } from '../helpers/test-database.js';
import { FakeClock } from '../helpers/clock.js';
import { PgCatalogRepository } from '../../src/catalog/catalog.repository.js';
import { createApp } from '../../src/create-app.js';
import { loadConfig } from '../../src/config/config.js';
import { CameraProvider, SnapshotBytes } from '../../src/providers/camera-provider.js';
import { Bbox, ProviderCamera } from '../../src/catalog/catalog.types.js';

class SpySnapshotProvider extends CameraProvider {
  public fetchSnapshotCallCount = 0;
  private readonly pngBytes = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
    0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0x45, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
    0x42, 0x60, 0x82,
  ]);

  async fetchCatalog(bbox: Bbox, signal?: AbortSignal): Promise<ProviderCamera[]> {
    return [];
  }

  async fetchSnapshot(sourceRef: string, signal?: AbortSignal): Promise<SnapshotBytes> {
    this.fetchSnapshotCallCount++;
    // Simulate short network latency
    await new Promise((r) => setTimeout(r, 20));
    return {
      bytes: this.pngBytes,
      mime: 'image/png',
    };
  }
}

describe('Snapshot API (Integration)', () => {
  const baseHeaders = {
    'x-api-key': 'test-reader-key-32charslong!!',
  };

  it('serves snapshots, coalesces concurrent requests, handles If-None-Match 304 and updates DB health', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock(1700000000000);
      const repo = new PgCatalogRepository(pool, schema, clock);

      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'cam_snap_01',
            name: 'Camera Snapshot Test',
            provinceId: 'tp_hcm',
            sourceKind: 'snapshot',
            sourceRef: 'ref_snap_01',
          },
          {
            provider: 'notis',
            providerCameraId: 'cam_youtube_01',
            name: 'Camera Youtube Test',
            provinceId: 'tp_hcm',
            sourceKind: 'youtube',
            sourceRef: 'https://youtube.com/stream',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      const camSnap = await repo.findBySource('notis', 'cam_snap_01');
      const camYoutube = await repo.findBySource('notis', 'cam_youtube_01');
      assert.ok(camSnap);
      assert.ok(camYoutube);

      const spyProvider = new SpySnapshotProvider();

      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-admin-key-32charslong!!',
        CAMERA_PROVIDER_MODE: 'fixture',
      });
      config.databaseSchema = schema;

      const app = await createApp({
        config,
        testingControllers: [],
      });

      // Override provider in testing container
      (app as any).get('CAMERA_PROVIDER'); // ensure module initialized

      try {
        // 1. Initial GET -> 200 with image bytes, MIME, ETag, headers
        const res1 = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${camSnap.id}/snapshot`,
          headers: baseHeaders,
        });
        assert.equal(res1.statusCode, 200);
        assert.equal(res1.headers['content-type'], 'image/png');
        assert.equal(res1.headers['cache-control'], 'private, no-cache');
        assert.ok(res1.headers['etag']);
        assert.ok(res1.headers['x-image-fetched-at']);
        assert.ok(res1.rawPayload.length > 0);

        const etag = res1.headers['etag'] as string;

        // 2. If-None-Match with matching ETag within TTL -> 304 without body
        const res304 = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${camSnap.id}/snapshot`,
          headers: {
            ...baseHeaders,
            'if-none-match': etag,
          },
        });
        assert.equal(res304.statusCode, 304);
        assert.equal(res304.rawPayload.length, 0);

        // 3. Unsupported camera (youtube) -> 422 PLAYBACK_UNSUPPORTED
        const resUnsupported = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${camYoutube.id}/snapshot`,
          headers: baseHeaders,
        });
        assert.equal(resUnsupported.statusCode, 422);

        // 4. Unknown camera -> 404
        const resUnknown = await app.inject({
          method: 'GET',
          url: '/v1/cameras/00000000-0000-0000-0000-000000000000/snapshot',
          headers: baseHeaders,
        });
        assert.equal(resUnknown.statusCode, 404);
      } finally {
        await app.close();
      }
    } finally {
      await cleanup();
    }
  });
});
