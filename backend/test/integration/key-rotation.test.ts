import 'reflect-metadata';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Controller, Get, Post, UseGuards, HttpCode } from '@nestjs/common';
import { createApp } from '../../src/create-app.js';
import { loadConfig, AppConfig } from '../../src/config/config.js';
import { ApiKeyGuard } from '../../src/http/api-key.guard.js';
import { AdminOnly } from '../../src/http/admin-only.decorator.js';

// T07 / T06-D3: key rotation overlap window, end to end at the HTTP layer.
// While BACKEND_API_KEY_PREVIOUS is configured, apps built with the old
// reader key keep working on reader routes; the old key never gains admin
// rights; once the variable is removed the old key is dead (401).

@Controller('test-rotation')
class TestRotationController {
  @Get('reader-protected')
  @UseGuards(ApiKeyGuard)
  readerProtected() {
    return { data: { success: true } };
  }

  @Post('admin-protected')
  @HttpCode(200)
  @UseGuards(ApiKeyGuard)
  @AdminOnly()
  adminProtected() {
    return { data: { adminSuccess: true } };
  }
}

describe('Key rotation overlap window (Integration)', () => {
  const baseEnv: NodeJS.ProcessEnv = {
    DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5432/camera_catalog',
    BACKEND_API_KEY: 'reader-current',
    ADMIN_API_KEY: 'admin-secret',
  };

  async function createTestApp(env: NodeJS.ProcessEnv) {
    const config: AppConfig = loadConfig(env);
    const loggerMock = {
      log: () => undefined,
      error: () => undefined,
      warn: () => undefined,
      debug: () => undefined,
      verbose: () => undefined,
    };
    return createApp({
      config,
      logger: loggerMock as never,
      testingControllers: [TestRotationController],
    });
  }

  it('accepts current and previous reader keys on reader routes during the window', async () => {
    const app = await createTestApp({
      ...baseEnv,
      BACKEND_API_KEY_PREVIOUS: 'reader-previous',
    });
    try {
      for (const key of ['reader-current', 'reader-previous']) {
        const res = await app.inject({
          method: 'GET',
          url: '/test-rotation/reader-protected',
          headers: { 'x-api-key': key },
        });
        assert.equal(res.statusCode, 200, `expected 200 for ${key}`);
      }
    } finally {
      await app.close();
    }
  });

  it('denies the previous reader key on admin routes with 403 FORBIDDEN', async () => {
    const app = await createTestApp({
      ...baseEnv,
      BACKEND_API_KEY_PREVIOUS: 'reader-previous',
    });
    try {
      const res = await app.inject({
        method: 'POST',
        url: '/test-rotation/admin-protected',
        headers: { 'x-api-key': 'reader-previous' },
      });
      assert.equal(res.statusCode, 403);
      assert.equal(JSON.parse(res.payload).error.code, 'FORBIDDEN');
    } finally {
      await app.close();
    }
  });

  it('rejects the old key with 401 once the window is closed (variable removed)', async () => {
    const app = await createTestApp(baseEnv);
    try {
      const res = await app.inject({
        method: 'GET',
        url: '/test-rotation/reader-protected',
        headers: { 'x-api-key': 'reader-previous' },
      });
      assert.equal(res.statusCode, 401);
      assert.equal(JSON.parse(res.payload).error.code, 'UNAUTHORIZED');
    } finally {
      await app.close();
    }
  });
});
