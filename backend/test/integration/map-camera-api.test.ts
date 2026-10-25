import { it } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../../src/create-app.js';
import { loadConfig } from '../../src/config/config.js';
import {
  TEST_DATABASE_URL,
  createTestSchemaContext,
} from '../helpers/test-database.js';
import { PgCatalogRepository } from '../../src/catalog/catalog.repository.js';
it('map endpoint validates and authenticates before database access', async () => {
  const config = loadConfig({
    DATABASE_URL: TEST_DATABASE_URL,
    BACKEND_API_KEY: 'test-reader-key-32charslong!!',
    ADMIN_API_KEY: 'test-admin-key-32charslong!!',
  });
  const app = await createApp({ config });
  try {
    for (const key of [undefined, 'wrong'])
      assert.equal(
        (
          await app.inject({
            url: '/v1/map-cameras',
            headers: key ? { 'x-api-key': key } : {},
          })
        ).statusCode,
        401
      );
    for (const key of [config.backendApiKey, config.adminApiKey]) {
      const res = await app.inject({
        url: '/v1/map-cameras?provinceId=tp_hcm&bbox=invalid',
        headers: { 'x-api-key': key },
      });
      assert.equal(res.statusCode, 400);
      assert.equal(res.json().error.code, 'INVALID_INPUT');
    }
  } finally {
    await app.close();
  }
});
it('returns bounded sanitized spatial results in both modes and leaves list/detail intact', async () => {
  const ctx = await createTestSchemaContext();
  const config = loadConfig({
    DATABASE_URL: TEST_DATABASE_URL,
    BACKEND_API_KEY: 'test-reader-key-32charslong!!',
    ADMIN_API_KEY: 'test-admin-key-32charslong!!',
  });
  config.databaseSchema = ctx.schema;
  const repo = new PgCatalogRepository(ctx.pool, ctx.schema);
  await repo.commitImport({
    provider: 'notis',
    provinceId: 'tp_hcm',
    bbox: [106, 10, 107, 11],
    fetchedAt: new Date(),
    cameras: Array.from({ length: 201 }, (_, i) => ({
      provider: 'notis',
      providerCameraId: String(i),
      provinceId: 'tp_hcm',
      name: `Camera ${i}`,
      district: 'Quận 1',
      location: { lat: 10.77, lng: 106.7 },
      sourceKind: 'snapshot' as const,
      sourceRef: 'SECRET_TOKEN',
    })),
  });
  const app = await createApp({ config });
  const headers = { 'x-api-key': config.backendApiKey };
  try {
    for (const query of [
      'bbox=106,10,107,11',
      'lat=10.77&lng=106.7&radiusMeters=1000',
    ]) {
      const res = await app.inject({
        url: `/v1/map-cameras?provinceId=tp_hcm&${query}&district=quan%201`,
        headers,
      });
      assert.equal(res.statusCode, 200);
      const body = res.json();
      assert.deepEqual(body.meta.result, {
        limit: 200,
        returned: 200,
        hasMore: true,
      });
      assert.equal(body.data.length, 200);
      assert.equal(res.payload.includes('SECRET_TOKEN'), false);
      assert.equal(res.payload.includes('sourceRef'), false);
      assert.deepEqual(
        body.data.map((x: any) => x.camera.id),
        body.data.map((x: any) => x.camera.id).sort()
      );
      assert.equal(
        body.data[0].distanceMeters,
        query.startsWith('bbox') ? null : 0
      );
    }
    const zero = await app.inject({
      url: '/v1/map-cameras?provinceId=tp_hcm&bbox=0,0,1,1',
      headers,
    });
    assert.deepEqual(zero.json().meta.result, {
      limit: 200,
      returned: 0,
      hasMore: false,
    });
    const list = await app.inject({
      url: '/v1/cameras?provinceId=tp_hcm',
      headers,
    });
    assert.equal(list.json().meta.page.total, 201);
    const id = list.json().data[0].id;
    assert.equal(
      (await app.inject({ url: `/v1/cameras/${id}`, headers })).statusCode,
      200
    );
  } finally {
    await app.close();
    await ctx.cleanup();
  }
});
it('map endpoint supports key rotation and existing rate limits', async () => {
  const env = {
    DATABASE_URL: TEST_DATABASE_URL,
    BACKEND_API_KEY: 'reader-current',
    ADMIN_API_KEY: 'admin-current',
    BACKEND_API_KEY_PREVIOUS: 'reader-previous',
  };
  for (const previous of [true, false]) {
    const config = loadConfig({
      ...env,
      BACKEND_API_KEY_PREVIOUS: previous
        ? env.BACKEND_API_KEY_PREVIOUS
        : undefined,
    });
    config.rateLimitMaxPerMinute = 1;
    const app = await createApp({ config });
    try {
      const url = '/v1/map-cameras?provinceId=tp_hcm&bbox=invalid';
      const res = await app.inject({
        url,
        headers: { 'x-api-key': 'reader-previous' },
      });
      assert.equal(res.statusCode, previous ? 400 : 401);
      if (previous)
        assert.equal(
          (
            await app.inject({
              url,
              headers: { 'x-api-key': 'reader-previous' },
            })
          ).statusCode,
          429
        );
    } finally {
      await app.close();
    }
  }
});
