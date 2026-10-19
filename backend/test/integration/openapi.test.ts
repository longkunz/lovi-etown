import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../../src/create-app.js';
import { loadConfig } from '../../src/config/config.js';
import { TEST_DATABASE_URL } from '../helpers/test-database.js';

describe('OpenAPI & Swagger Documentation (Integration)', () => {
  it('generates compliant OpenAPI 3.0 document covering all camera-first routes and security schemas', async () => {
    const config = loadConfig({
      DATABASE_URL: TEST_DATABASE_URL,
      BACKEND_API_KEY: 'test-reader-key-32charslong!!',
      ADMIN_API_KEY: 'test-admin-key-32charslong!!',
      CAMERA_PROVIDER_MODE: 'fixture',
    });

    const app = await createApp({ config });
    try {
      const res = await app.inject({
        method: 'GET',
        url: '/docs-json',
      });

      assert.equal(res.statusCode, 200);
      const spec = JSON.parse(res.payload);

      assert.equal(spec.openapi?.startsWith('3.'), true);
      assert.equal(spec.info?.title, 'Camera Backend API');

      // Assert paths exist
      const paths = Object.keys(spec.paths);
      assert.ok(paths.includes('/v1/cameras'));
      assert.ok(paths.includes('/v1/camera-districts'));
      assert.ok(paths.includes('/v1/cameras/{id}'));
      assert.ok(paths.includes('/v1/cameras/{id}/playback'));
      assert.ok(paths.includes('/v1/cameras/{id}/related'));
      assert.ok(paths.includes('/v1/cameras/{id}/snapshot'));
      assert.ok(paths.includes('/v1/admin/camera-providers/notis/sync'));

      // Assert no deferred/foreign endpoints leaked
      for (const p of paths) {
        assert.equal(p.includes('vietmap'), false, `Route ${p} should not reference vietmap`);
        assert.equal(p.includes('udrivex'), false, `Route ${p} should not reference udrivex`);
      }

      // Security schemes: ApiKeyAuth with x-api-key header
      assert.ok(spec.components?.securitySchemes?.ApiKeyAuth);
      assert.equal(spec.components.securitySchemes.ApiKeyAuth.name, 'x-api-key');
    } finally {
      await app.close();
    }
  });
});
