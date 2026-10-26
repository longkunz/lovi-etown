import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createTestSchemaContext } from '../helpers/test-database.js';
import { FakeClock } from '../helpers/clock.js';
import { PgCatalogRepository } from '../../src/catalog/catalog.repository.js';
import { ProviderCamera } from '../../src/catalog/catalog.types.js';

describe('Catalog Repository (Integration)', () => {
  it('counts only online cameras per district within the requested province', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);
      const statuses = ['online', 'offline', 'degraded', 'unknown'] as const;
      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        fetchedAt: clock.nowDate(),
        cameras: [
          ...statuses.map((status): ProviderCamera => ({
            provider: 'notis', providerCameraId: status, name: status,
            provinceId: 'tp_hcm', district: 'Quận 1',
            sourceKind: 'snapshot', sourceRef: status,
          })),
          ...['Quận 3', null, ''].map((district, i): ProviderCamera => ({
            provider: 'notis', providerCameraId: `extra_${i}`, name: `Extra ${i}`,
            provinceId: 'tp_hcm', district,
            sourceKind: 'snapshot', sourceRef: `extra_${i}`,
          })),
        ],
      });
      const catalog = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      for (const camera of catalog.items) {
        const status = camera.providerCameraId;
        if (status === 'online' || status === 'offline' || status === 'degraded') {
          await repo.updateAvailability(camera.id, status, clock.nowDate());
        } else if (camera.district === 'Quận 3') {
          await repo.updateAvailability(camera.id, 'offline', clock.nowDate());
        }
      }
      await repo.commitImport({
        provider: 'notis', provinceId: 'ha_noi',
        bbox: [105.7, 20.9, 105.9, 21.1], fetchedAt: clock.nowDate(),
        cameras: [{
          provider: 'notis', providerCameraId: 'other_province', name: 'Other province',
          provinceId: 'ha_noi', district: 'Quận 1',
          sourceKind: 'snapshot', sourceRef: 'other_province',
        }],
      });
      const other = await repo.list({ provinceId: 'ha_noi', limit: 50, offset: 0 });
      await repo.updateAvailability(other.items[0].id, 'online', clock.nowDate());

      assert.deepEqual(await repo.districts('tp_hcm'), [
        { district: 'Quận 1', cameraCount: 4, onlineCount: 1 },
        { district: 'Quận 3', cameraCount: 1, onlineCount: 0 },
      ]);
      assert.deepEqual(await repo.districts('ha_noi'), [
        { district: 'Quận 1', cameraCount: 1, onlineCount: 1 },
      ]);
    } finally {
      await cleanup();
    }
  });

  it('imports same camera twice preserving stable domain UUID and updating metadata without duplicates', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock(1700000000000);
      const repo = new PgCatalogRepository(pool, schema, clock);

      const camera: ProviderCamera = {
        provider: 'notis',
        providerCameraId: 'cam_001',
        name: 'Camera Nguyễn Huệ - Lê Lợi',
        provinceId: 'tp_hcm',
        address: 'Giao lộ Nguyễn Huệ - Lê Lợi',
        district: 'Quận 1',
        location: { lat: 10.7745, lng: 106.7032 },
        sourceKind: 'snapshot',
        sourceRef: 'notis_ref_001',
      };

      const res1 = await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [camera],
        fetchedAt: clock.nowDate(),
      });

      assert.equal(res1.upsertedCount, 1);
      const list1 = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(list1.total, 1);
      const initialId = list1.items[0].id;
      assert.ok(initialId);

      // Re-import with updated name
      clock.advance(1000);
      const cameraUpdated: ProviderCamera = {
        ...camera,
        name: 'Camera Nguyễn Huệ - Lê Lợi (Cập nhật)',
      };

      const res2 = await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [cameraUpdated],
        fetchedAt: clock.nowDate(),
      });

      assert.equal(res2.upsertedCount, 1);
      const list2 = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(list2.total, 1);
      assert.equal(list2.items[0].id, initialId, 'Domain UUID must remain stable across imports');
      assert.equal(list2.items[0].name, 'Camera Nguyễn Huệ - Lê Lợi (Cập nhật)');
    } finally {
      await cleanup();
    }
  });

  it('handles two cameras with same name but different provider IDs as distinct stable records', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);

      const cameras: ProviderCamera[] = [
        {
          provider: 'notis',
          providerCameraId: 'id_alpha',
          name: 'Camera Ngã Tư Hàng Xanh',
          provinceId: 'tp_hcm',
          district: 'Bình Thạnh',
          sourceKind: 'snapshot',
          sourceRef: 'ref_a',
        },
        {
          provider: 'notis',
          providerCameraId: 'id_beta',
          name: 'Camera Ngã Tư Hàng Xanh',
          provinceId: 'tp_hcm',
          district: 'Bình Thạnh',
          sourceKind: 'snapshot',
          sourceRef: 'ref_b',
        },
      ];

      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras,
        fetchedAt: clock.nowDate(),
      });

      const list = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(list.total, 2);
      assert.notEqual(list.items[0].id, list.items[1].id);
    } finally {
      await cleanup();
    }
  });

  it('rolls back completely on injected import failure, preserving old version and items', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);

      // Initial successful import
      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'cam_initial',
            name: 'Camera Ban Đầu',
            provinceId: 'tp_hcm',
            sourceKind: 'snapshot',
            sourceRef: 'ref_init',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      const before = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(before.total, 1);
      const initialVersion = before.catalog.version;

      // Injected failure during transaction
      await assert.rejects(
        async () => {
          await repo.commitImport({
            provider: 'notis',
            provinceId: 'tp_hcm',
            bbox: [106.69, 10.76, 106.71, 10.78],
            cameras: [
              {
                provider: 'notis',
                providerCameraId: 'cam_bad',
                name: null as any, // Violates NOT NULL constraint
                provinceId: 'tp_hcm',
                sourceKind: 'snapshot',
                sourceRef: 'ref_bad',
              },
            ],
            fetchedAt: clock.nowDate(),
          });
        }
      );

      // Verify catalog remains pristine
      const after = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(after.total, 1);
      assert.equal(after.items[0].providerCameraId, 'cam_initial');
      assert.equal(after.catalog.version, initialVersion);
    } finally {
      await cleanup();
    }
  });

  it('does not delete existing cameras when subsequent response omits them (no absence deletion)', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);

      // Import 2 cameras
      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'cam_1',
            name: 'Camera 1',
            provinceId: 'tp_hcm',
            sourceKind: 'snapshot',
            sourceRef: 'ref_1',
          },
          {
            provider: 'notis',
            providerCameraId: 'cam_2',
            name: 'Camera 2',
            provinceId: 'tp_hcm',
            sourceKind: 'snapshot',
            sourceRef: 'ref_2',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      // Second import with only camera 1
      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'cam_1',
            name: 'Camera 1 Updated',
            provinceId: 'tp_hcm',
            sourceKind: 'snapshot',
            sourceRef: 'ref_1',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      const list = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(list.total, 2, 'Camera 2 must NOT be deleted due to absence');
    } finally {
      await cleanup();
    }
  });

  it('filters by exact normalized district and searches both name and address without accents', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);

      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'q1_1',
            name: 'Ngã tư Đồng Khởi - Lê Thánh Tôn',
            provinceId: 'tp_hcm',
            district: 'Quận 1',
            address: 'Số 1 Đồng Khởi',
            sourceKind: 'snapshot',
            sourceRef: 'ref_q1',
          },
          {
            provider: 'notis',
            providerCameraId: 'q3_1',
            name: 'Hồ Con Rùa',
            provinceId: 'tp_hcm',
            district: 'Quận 3',
            address: 'Vòng xoay Công trường Quốc Tế',
            sourceKind: 'snapshot',
            sourceRef: 'ref_q3',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      // Filter by district
      const q1Result = await repo.list({ provinceId: 'tp_hcm', district: 'quận 1', limit: 50, offset: 0 });
      assert.equal(q1Result.total, 1);
      assert.equal(q1Result.items[0].providerCameraId, 'q1_1');

      // Search by unaccented name
      const searchName = await repo.list({ provinceId: 'tp_hcm', q: 'dong khoi', limit: 50, offset: 0 });
      assert.equal(searchName.total, 1);
      assert.equal(searchName.items[0].providerCameraId, 'q1_1');

      // Search by unaccented address
      const searchAddress = await repo.list({ provinceId: 'tp_hcm', q: 'quoc te', limit: 50, offset: 0 });
      assert.equal(searchAddress.total, 1);
      assert.equal(searchAddress.items[0].providerCameraId, 'q3_1');
    } finally {
      await cleanup();
    }
  });

  it('keeps camera with location null listable and does not default to (0,0)', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);

      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'null_loc',
            name: 'Camera Không Tọa Độ',
            provinceId: 'tp_hcm',
            location: null,
            sourceKind: 'snapshot',
            sourceRef: 'ref_null_loc',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      const list = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(list.total, 1);
      assert.equal(list.items[0].location, null);

      const found = await repo.find(list.items[0].id);
      assert.ok(found);
      assert.equal(found.location, null);
    } finally {
      await cleanup();
    }
  });

  it('calculates catalog state: never_synced on empty DB, and derived isStale on age > threshold', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock(1700000000000);
      const repo = new PgCatalogRepository(pool, schema, clock);

      // Empty DB
      const initial = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(initial.catalog.syncState, 'never_synced');
      assert.equal(initial.catalog.coverage, 'unknown');
      assert.equal(initial.catalog.fetchedAt, null);
      assert.equal(initial.catalog.isStale, false);

      // Import
      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'c1',
            name: 'Camera C1',
            provinceId: 'tp_hcm',
            sourceKind: 'snapshot',
            sourceRef: 'r1',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      const synced = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(synced.catalog.syncState, 'synced');
      assert.equal(synced.catalog.isStale, false);

      // Advance clock past 86400000 ms (24 hours)
      clock.advance(86400000 + 1000);
      const staleCheck = await repo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
      assert.equal(staleCheck.catalog.isStale, true);
    } finally {
      await cleanup();
    }
  });

  it('runs migrations twice idempotently and safely', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const { runMigrations } = await import('../../src/database/migrate.js');
      // Second run on same schema should apply 0 migrations
      const appliedAgain = await runMigrations({ pool, schema });
      assert.equal(appliedAgain.length, 0);
    } finally {
      await cleanup();
    }
  });

  it('retains persisted records when database pool is restarted', async () => {
    const { pool, schema, cleanup } = await createTestSchemaContext();
    try {
      const clock = new FakeClock();
      const repo = new PgCatalogRepository(pool, schema, clock);

      await repo.commitImport({
        provider: 'notis',
        provinceId: 'tp_hcm',
        bbox: [106.69, 10.76, 106.71, 10.78],
        cameras: [
          {
            provider: 'notis',
            providerCameraId: 'persist_cam_1',
            name: 'Persisted Camera',
            provinceId: 'tp_hcm',
            sourceKind: 'snapshot',
            sourceRef: 'ref_persist',
          },
        ],
        fetchedAt: clock.nowDate(),
      });

      // Close and create new pool
      await pool.end();
      const { TEST_DATABASE_URL } = await import('../helpers/test-database.js');
      const pgModule = await import('pg');
      const newPool = new pgModule.default.Pool({ connectionString: TEST_DATABASE_URL });

      try {
        const newRepo = new PgCatalogRepository(newPool, schema, clock);
        const list = await newRepo.list({ provinceId: 'tp_hcm', limit: 50, offset: 0 });
        assert.equal(list.total, 1);
        assert.equal(list.items[0].providerCameraId, 'persist_cam_1');
      } finally {
        await newPool.end();
      }
    } finally {
      // Re-create minimal pool just to drop schema
      const { TEST_DATABASE_URL } = await import('../helpers/test-database.js');
      const pgModule = await import('pg');
      const dropPool = new pgModule.default.Pool({ connectionString: TEST_DATABASE_URL });
      const client = await dropPool.connect();
      try {
        await client.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
      } finally {
        client.release();
        await dropPool.end();
      }
    }
  });

  it('health ready endpoint returns 200 with DB and 503 when DB is unavailable', async () => {
    const { createApp } = await import('../../src/create-app.js');
    const { loadConfig } = await import('../../src/config/config.js');
    const { TEST_DATABASE_URL } = await import('../helpers/test-database.js');

    // 1. Valid DB connection -> 200
    const configOk = loadConfig({
      DATABASE_URL: TEST_DATABASE_URL,
      BACKEND_API_KEY: 'valid-test-key-for-health-check!!',
      ADMIN_API_KEY: 'admin-test-key-for-health-check!!',
    });
    const appOk = await createApp({ config: configOk });
    try {
      const res = await appOk.inject({ method: 'GET', url: '/health/ready' });
      assert.equal(res.statusCode, 200);
      const json = JSON.parse(res.payload);
      assert.equal(json.data.status, 'ready');
      assert.equal(json.data.database, 'ready');
    } finally {
      await appOk.close();
    }

    // 2. Unavailable DB -> 503
    const configBad = loadConfig({
      DATABASE_URL: 'postgresql://postgres:bad_password@127.0.0.1:5439/nonexistent_db',
      BACKEND_API_KEY: 'valid-test-key-for-health-check!!',
      ADMIN_API_KEY: 'admin-test-key-for-health-check!!',
    });
    const appBad = await createApp({ config: configBad });
    try {
      const res = await appBad.inject({ method: 'GET', url: '/health/ready' });
      assert.equal(res.statusCode, 503);
      const json = JSON.parse(res.payload);
      assert.equal(json.error.code, 'SERVICE_UNAVAILABLE');
    } finally {
      await appBad.close();
    }
  });
});
