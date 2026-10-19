import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createTestSchemaContext, TEST_DATABASE_URL } from '../helpers/test-database.js';
import { FakeClock } from '../helpers/clock.js';
import { PgCatalogRepository } from '../../src/catalog/catalog.repository.js';
import { createApp } from '../../src/create-app.js';
import { loadConfig } from '../../src/config/config.js';
import { ProviderCamera } from '../../src/catalog/catalog.types.js';

describe('Camera Public APIs (Integration)', () => {
  const baseHeaders = {
    'x-api-key': 'test-reader-key-32charslong!!',
  };

  async function seedTestCameras(repo: PgCatalogRepository) {
    const cameras: ProviderCamera[] = [
      {
        provider: 'notis',
        providerCameraId: 'cam_q1_01',
        name: 'Camera Lê Lợi - Pasteur',
        provinceId: 'tp_hcm',
        district: 'Quận 1',
        address: 'Số 10 Lê Lợi',
        location: { lat: 10.7738, lng: 106.7011 },
        sourceKind: 'snapshot',
        sourceRef: 'ref_q1_01',
      },
      {
        provider: 'notis',
        providerCameraId: 'cam_q1_02',
        name: 'Camera Đồng Khởi',
        provinceId: 'tp_hcm',
        district: 'Quận 1',
        address: 'Công viên Lam Sơn',
        location: { lat: 10.7761, lng: 106.7035 },
        sourceKind: 'snapshot',
        sourceRef: 'ref_q1_02',
      },
      {
        provider: 'notis',
        providerCameraId: 'cam_q3_01',
        name: 'Camera Hồ Con Rùa',
        provinceId: 'tp_hcm',
        district: 'Quận 3',
        address: 'Công trường Quốc Tế',
        location: { lat: 10.7827, lng: 106.6958 },
        sourceKind: 'snapshot',
        sourceRef: 'ref_q3_01',
      },
      {
        provider: 'notis',
        providerCameraId: 'cam_nodist_01',
        name: 'Camera Vành Đai Ngoại Ô',
        provinceId: 'tp_hcm',
        district: null,
        address: null,
        location: null,
        sourceKind: 'snapshot',
        sourceRef: 'ref_nodist_01',
      },
      {
        provider: 'notis',
        providerCameraId: 'cam_stream_only',
        name: 'Camera Kênh Trực Tuyến Live',
        provinceId: 'tp_hcm',
        district: 'Quận 1',
        address: 'Hàm Nghi',
        location: { lat: 10.7711, lng: 106.7022 },
        sourceKind: 'youtube', // unsupported playback in A1
        sourceRef: 'https://youtube.com/live_test',
      },
    ];

    await repo.commitImport({
      provider: 'notis',
      provinceId: 'tp_hcm',
      bbox: [106.69, 10.76, 106.71, 10.78],
      cameras,
      fetchedAt: new Date(1700000000000),
    });
  }

  it('GET /v1/cameras: lists cameras with pagination, search, district filter and sanitized DTOs', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock(1700000000000);
      const repo = new PgCatalogRepository(pool, schema, clock);
      await seedTestCameras(repo);

      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-admin-key-32charslong!!',
      });
      config.databaseSchema = schema;

      const app = await createApp({ config });
      try {
        // Set search path for injected requests if necessary
        // 1. Full list
        const resList = await app.inject({
          method: 'GET',
          url: '/v1/cameras?provinceId=tp_hcm&limit=10&offset=0',
          headers: baseHeaders,
        });
        assert.equal(resList.statusCode, 200);
        const jsonList = JSON.parse(resList.payload);
        assert.equal(jsonList.data.length, 5);
        assert.equal(jsonList.meta.page.total, 5);
        assert.equal(jsonList.meta.catalog.syncState, 'synced');

        // Check DTO sanitization: no internal sourceRef, providerCameraId, or secrets
        const first = jsonList.data[0];
        assert.ok(first.id);
        assert.ok(first.name);
        assert.ok(first.playbackEndpoint);
        assert.equal(first.sourceRef, undefined);
        assert.equal(first.providerCameraId, undefined);

        // 2. Search unaccented "le loi"
        const resSearch = await app.inject({
          method: 'GET',
          url: '/v1/cameras?provinceId=tp_hcm&q=le loi',
          headers: baseHeaders,
        });
        assert.equal(resSearch.statusCode, 200);
        const jsonSearch = JSON.parse(resSearch.payload);
        assert.equal(jsonSearch.data.length, 1);
        assert.equal(jsonSearch.data[0].name, 'Camera Lê Lợi - Pasteur');

        // 3. District filter "quận 1"
        const resDistrict = await app.inject({
          method: 'GET',
          url: '/v1/cameras?provinceId=tp_hcm&district=quận 1',
          headers: baseHeaders,
        });
        assert.equal(resDistrict.statusCode, 200);
        const jsonDist = JSON.parse(resDistrict.payload);
        assert.equal(jsonDist.data.length, 3);

        // 4. Unknown query parameter rejected
        const resUnknownQuery = await app.inject({
          method: 'GET',
          url: '/v1/cameras?provinceId=tp_hcm&unexpectedParam=123',
          headers: baseHeaders,
        });
        assert.equal(resUnknownQuery.statusCode, 400);

        // 5. Query q of length 1 rejected
        const resShortQ = await app.inject({
          method: 'GET',
          url: '/v1/cameras?provinceId=tp_hcm&q=a',
          headers: baseHeaders,
        });
        assert.equal(resShortQ.statusCode, 400);

        // 6. Unsupported province rejected
        const resBadProvince = await app.inject({
          method: 'GET',
          url: '/v1/cameras?provinceId=ha_noi',
          headers: baseHeaders,
        });
        assert.equal(resBadProvince.statusCode, 400);
        const jsonBadProv = JSON.parse(resBadProvince.payload);
        assert.equal(jsonBadProv.error.code, 'UNSUPPORTED_PROVINCE');
      } finally {
        await app.close();
      }
    } finally {
      await cleanup();
    }
  });

  it('GET /v1/camera-districts: returns distinct non-null district counts', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);
      await seedTestCameras(repo);

      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-admin-key-32charslong!!',
      });
      config.databaseSchema = schema;

      const app = await createApp({ config });
      try {
        const res = await app.inject({
          method: 'GET',
          url: '/v1/camera-districts?provinceId=tp_hcm',
          headers: baseHeaders,
        });
        assert.equal(res.statusCode, 200);
        const json = JSON.parse(res.payload);
        assert.ok(Array.isArray(json.data));
        // Quận 1 (3 cameras), Quận 3 (1 camera)
        assert.equal(json.data.length, 2);
        assert.equal(json.data[0].district, 'Quận 1');
        assert.equal(json.data[0].cameraCount, 3);
        assert.equal(json.data[1].district, 'Quận 3');
        assert.equal(json.data[1].cameraCount, 1);
      } finally {
        await app.close();
      }
    } finally {
      await cleanup();
    }
  });

  it('GET /v1/cameras/{id}: detail returns single camera or 404 for unknown UUID, 400 for malformed UUID', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);
      await seedTestCameras(repo);

      const list = await repo.list({ provinceId: 'tp_hcm', limit: 1, offset: 0 });
      const existingId = list.items[0].id;

      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-admin-key-32charslong!!',
      });
      config.databaseSchema = schema;

      const app = await createApp({ config });
      try {
        // Valid existing ID
        const resExisting = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${existingId}`,
          headers: baseHeaders,
        });
        assert.equal(resExisting.statusCode, 200);
        const jsonExisting = JSON.parse(resExisting.payload);
        assert.equal(jsonExisting.data.id, existingId);

        // Unknown UUID -> 404
        const resUnknown = await app.inject({
          method: 'GET',
          url: '/v1/cameras/00000000-0000-0000-0000-000000000000',
          headers: baseHeaders,
        });
        assert.equal(resUnknown.statusCode, 404);
        const jsonUnknown = JSON.parse(resUnknown.payload);
        assert.equal(jsonUnknown.error.code, 'NOT_FOUND');

        // Malformed UUID -> 400
        const resMalformed = await app.inject({
          method: 'GET',
          url: '/v1/cameras/not-a-valid-uuid-format',
          headers: baseHeaders,
        });
        assert.equal(resMalformed.statusCode, 400);
        const jsonMalformed = JSON.parse(resMalformed.payload);
        assert.equal(jsonMalformed.error.code, 'INVALID_INPUT');
      } finally {
        await app.close();
      }
    } finally {
      await cleanup();
    }
  });

  it('GET /v1/cameras/{id}/playback: descriptor returns snapshot kind or 422 for unsupported stream', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);
      await seedTestCameras(repo);

      const snapshotCam = await repo.findBySource('notis', 'cam_q1_01');
      const youtubeCam = await repo.findBySource('notis', 'cam_stream_only');
      assert.ok(snapshotCam);
      assert.ok(youtubeCam);

      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-admin-key-32charslong!!',
      });
      config.databaseSchema = schema;

      const app = await createApp({ config });
      try {
        // Snapshot camera -> 200 descriptor
        const resSnap = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${snapshotCam.id}/playback`,
          headers: baseHeaders,
        });
        assert.equal(resSnap.statusCode, 200);
        const jsonSnap = JSON.parse(resSnap.payload);
        assert.equal(jsonSnap.data.kind, 'snapshot');
        assert.equal(jsonSnap.data.refreshIntervalMs, 12000);
        assert.equal(jsonSnap.data.capturedAt, null);
        assert.equal(jsonSnap.data.snapshotEndpoint, `/v1/cameras/${snapshotCam.id}/snapshot`);

        // YouTube stream camera -> 422 PLAYBACK_UNSUPPORTED
        const resYoutube = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${youtubeCam.id}/playback`,
          headers: baseHeaders,
        });
        assert.equal(resYoutube.statusCode, 422);
        const jsonYoutube = JSON.parse(resYoutube.payload);
        assert.equal(jsonYoutube.error.code, 'PLAYBACK_UNSUPPORTED');
      } finally {
        await app.close();
      }
    } finally {
      await cleanup();
    }
  });

  it('GET /v1/cameras/{id}/related: excludes self, handles null district with DISTRICT_UNKNOWN reason, 404 for unknown camera', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);
      await seedTestCameras(repo);

      const q1Cam1 = await repo.findBySource('notis', 'cam_q1_01');
      const noDistCam = await repo.findBySource('notis', 'cam_nodist_01');
      assert.ok(q1Cam1);
      assert.ok(noDistCam);

      const config = loadConfig({
        DATABASE_URL: TEST_DATABASE_URL,
        BACKEND_API_KEY: 'test-reader-key-32charslong!!',
        ADMIN_API_KEY: 'test-admin-key-32charslong!!',
      });
      config.databaseSchema = schema;

      const app = await createApp({ config });
      try {
        // Known camera with district: returns other cameras in same district, excludes self
        const resRelated = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${q1Cam1.id}/related?limit=5`,
          headers: baseHeaders,
        });
        assert.equal(resRelated.statusCode, 200);
        const jsonRelated = JSON.parse(resRelated.payload);
        assert.ok(Array.isArray(jsonRelated.data));
        assert.equal(jsonRelated.data.length, 2); // cam_q1_02 and cam_stream_only
        assert.ok(jsonRelated.data.every((c: any) => c.id !== q1Cam1.id));

        // Known camera with null district: returns empty data with reason DISTRICT_UNKNOWN
        const resNullDist = await app.inject({
          method: 'GET',
          url: `/v1/cameras/${noDistCam.id}/related`,
          headers: baseHeaders,
        });
        assert.equal(resNullDist.statusCode, 200);
        const jsonNullDist = JSON.parse(resNullDist.payload);
        assert.deepEqual(jsonNullDist.data, []);
        assert.equal(jsonNullDist.meta.reason, 'DISTRICT_UNKNOWN');

        // Unknown camera UUID -> 404
        const resUnknown = await app.inject({
          method: 'GET',
          url: '/v1/cameras/00000000-0000-0000-0000-000000000000/related',
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
