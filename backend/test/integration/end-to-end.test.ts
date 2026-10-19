import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createTestSchemaContext, TEST_DATABASE_URL } from '../helpers/test-database.js';
import { createApp } from '../../src/create-app.js';
import { loadConfig } from '../../src/config/config.js';

describe('End-to-End Local Acceptance (Integration)', () => {
  const readerHeaders = {
    'x-api-key': 'test-reader-key-32charslong!!',
  };
  const adminHeaders = {
    'x-api-key': 'test-admin-key-32charslong!!',
  };

  it('executes full end-to-end lifecycle: sync -> list -> search -> detail -> playback -> snapshot -> restart persistence', async () => {
    const { schema, cleanup } = await createTestSchemaContext();

    try {
      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-admin-key-32charslong!!',
        CAMERA_PROVIDER_MODE: 'fixture',
      });
      config.databaseSchema = schema;

      // --- Phase 1: Initial App Boot & Health Check ---
      let app = await createApp({ config });
      let cameraId: string;
      let snapshotEtag: string;

      try {
        const liveRes = await app.inject({ method: 'GET', url: '/health/live' });
        assert.equal(liveRes.statusCode, 200);

        const readyRes = await app.inject({ method: 'GET', url: '/health/ready' });
        assert.equal(readyRes.statusCode, 200);

        // --- Phase 2: Admin Catalog Synchronization ---
        const syncRes = await app.inject({
          method: 'POST',
          url: '/v1/admin/camera-providers/notis/sync',
          headers: adminHeaders,
          payload: {
            bbox: [106.6, 10.7, 106.8, 10.8],
          },
        });
        assert.equal(syncRes.statusCode, 200);
        const syncBody = JSON.parse(syncRes.payload);
        assert.equal(syncBody.status, 'success');
        assert.ok(syncBody.upsertedCount > 0);

        // --- Phase 3: Public Catalog List & Search ---
        const listRes = await app.inject({
          method: 'GET',
          url: '/v1/cameras?provinceId=tp_hcm&limit=10',
          headers: readerHeaders,
        });
        assert.equal(listRes.statusCode, 200);
        const listBody = JSON.parse(listRes.payload);
        assert.ok(Array.isArray(listBody.data));
        assert.ok(listBody.data.length > 0);
        assert.equal(listBody.meta.catalog.syncState, 'synced');

        cameraId = listBody.data[0].id;
        const cameraName = listBody.data[0].name;

        // Search by prefix of camera name
        const searchRes = await app.inject({
          method: 'GET',
          url: `/v1/cameras?provinceId=tp_hcm&q=${encodeURIComponent(cameraName.slice(0, 4))}`,
          headers: readerHeaders,
        });
        assert.equal(searchRes.statusCode, 200);
        const searchBody = JSON.parse(searchRes.payload);
        assert.ok(searchBody.data.some((c: any) => c.id === cameraId));

        // --- Phase 4: Districts Aggregation ---
        const distRes = await app.inject({
          method: 'GET',
          url: '/v1/camera-districts?provinceId=tp_hcm',
          headers: readerHeaders,
        });
        assert.equal(distRes.statusCode, 200);
        const distBody = JSON.parse(distRes.payload);
        assert.ok(Array.isArray(distBody.data));


        // --- Phase 5: Camera Detail ---
        const detailRes = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${cameraId}`,
          headers: readerHeaders,
        });
        assert.equal(detailRes.statusCode, 200);
        const detailBody = JSON.parse(detailRes.payload);
        assert.equal(detailBody.data.id, cameraId);

        // --- Phase 6: Playback Descriptor ---
        const playbackRes = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${cameraId}/playback`,
          headers: readerHeaders,
        });
        assert.equal(playbackRes.statusCode, 200);
        const playbackBody = JSON.parse(playbackRes.payload);
        assert.equal(playbackBody.data.kind, 'snapshot');
        assert.equal(playbackBody.data.snapshotEndpoint, `/v1/cameras/${cameraId}/snapshot`);

        // --- Phase 7: Related Cameras ---
        const relatedRes = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${cameraId}/related`,
          headers: readerHeaders,
        });
        assert.equal(relatedRes.statusCode, 200);
        const relatedBody = JSON.parse(relatedRes.payload);
        assert.ok(Array.isArray(relatedBody.data));
        // Must exclude itself
        assert.ok(relatedBody.data.every((c: any) => c.id !== cameraId));

        // --- Phase 8: Snapshot Delivery and 304 Not Modified ---
        const snapRes = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${cameraId}/snapshot`,
          headers: readerHeaders,
        });
        assert.equal(snapRes.statusCode, 200);
        assert.equal(snapRes.headers['content-type'], 'image/png');
        assert.ok(snapRes.headers['etag']);
        snapshotEtag = snapRes.headers['etag'] as string;

        const snap304Res = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${cameraId}/snapshot`,
          headers: {
            ...readerHeaders,
            'if-none-match': snapshotEtag,
          },
        });
        assert.equal(snap304Res.statusCode, 304);
        assert.equal(snap304Res.rawPayload.length, 0);
      } finally {
        await app.close();
      }

      // --- Phase 9: App Restart Simulation (Persistent state) ---
      app = await createApp({ config });
      try {
        const detailAfterRestart = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${cameraId}`,
          headers: readerHeaders,
        });
        assert.equal(detailAfterRestart.statusCode, 200);
        const bodyAfterRestart = JSON.parse(detailAfterRestart.payload);
        assert.equal(bodyAfterRestart.data.id, cameraId, 'Camera domain UUID must remain identical after restart');
      } finally {
        await app.close();
      }
    } finally {
      await cleanup();
    }
  });
});
