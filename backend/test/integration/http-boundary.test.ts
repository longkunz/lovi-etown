import 'reflect-metadata';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Controller, Get, Post, Body, UseGuards, HttpCode } from '@nestjs/common';
import { createApp } from '../../src/create-app.js';
import { loadConfig, AppConfig } from '../../src/config/config.js';
import { ApiKeyGuard } from '../../src/http/api-key.guard.js';
import { AdminOnly } from '../../src/http/admin-only.decorator.js';

// Test-only controller used strictly for verifying HTTP boundaries
@Controller('test')
class TestBoundaryController {
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

  @Post('body-echo')
  bodyEcho(@Body() body: any) {
    if (body && body.unexpectedField !== undefined) {
      const err = new Error('Unexpected field');
      (err as any).status = 400;
      (err as any).code = 'VALIDATION_ERROR';
      throw err;
    }
    return { data: body };
  }
}

describe('HTTP Boundary & Authentication (Integration)', () => {
  const baseEnv: NodeJS.ProcessEnv = {
    DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5432/camera_catalog',
    BACKEND_API_KEY: 'valid-reader-api-key-test-value!!',
    ADMIN_API_KEY: 'valid-admin-api-key-test-value!!',
  };

  async function createTestApp(configOverrides: Partial<AppConfig> = {}, extraControllers: any[] = []) {
    const config = { ...loadConfig(baseEnv), ...configOverrides };
    const capturedLogs: string[] = [];
    const loggerMock = {
      log: (msg: string) => capturedLogs.push(msg),
      error: (msg: string) => capturedLogs.push(msg),
      warn: (msg: string) => capturedLogs.push(msg),
      debug: (msg: string) => capturedLogs.push(msg),
      verbose: (msg: string) => capturedLogs.push(msg),
    };

    const app = await createApp({
      config,
      logger: loggerMock as any,
      testingControllers: [TestBoundaryController, ...extraControllers],
    });

    return { app, capturedLogs, config };
  }

  it('allows anonymous access to GET /health/live without x-api-key', async () => {
    const { app } = await createTestApp();
    try {
      const res = await app.inject({
        method: 'GET',
        url: '/health/live',
      });
      assert.equal(res.statusCode, 200);
      const json = JSON.parse(res.payload);
      assert.equal(json.data.status, 'live');
      assert.ok(json.meta?.requestId);
      assert.equal(res.headers['x-request-id'], json.meta.requestId);
    } finally {
      await app.close();
    }
  });

  it('rejects protected route when x-api-key is missing or invalid', async () => {
    const { app } = await createTestApp();
    try {
      // Missing key
      const resMissing = await app.inject({
        method: 'GET',
        url: '/test/reader-protected',
      });
      assert.equal(resMissing.statusCode, 401);
      const jsonMissing = JSON.parse(resMissing.payload);
      assert.equal(jsonMissing.error.code, 'UNAUTHORIZED');
      assert.equal(jsonMissing.error.retryable, false);
      assert.ok(jsonMissing.error.requestId);
      assert.equal(resMissing.headers['x-request-id'], jsonMissing.error.requestId);

      // Invalid key
      const resInvalid = await app.inject({
        method: 'GET',
        url: '/test/reader-protected',
        headers: {
          'x-api-key': 'completely-wrong-api-key',
        },
      });
      assert.equal(resInvalid.statusCode, 401);
      const jsonInvalid = JSON.parse(resInvalid.payload);
      assert.equal(jsonInvalid.error.code, 'UNAUTHORIZED');
    } finally {
      await app.close();
    }
  });

  it('allows reader-protected route with valid BACKEND_API_KEY or ADMIN_API_KEY', async () => {
    const { app, config } = await createTestApp();
    try {
      // Reader key
      const resReader = await app.inject({
        method: 'GET',
        url: '/test/reader-protected',
        headers: {
          'x-api-key': config.backendApiKey,
        },
      });
      assert.equal(resReader.statusCode, 200);

      // Admin key
      const resAdmin = await app.inject({
        method: 'GET',
        url: '/test/reader-protected',
        headers: {
          'x-api-key': config.adminApiKey,
        },
      });
      assert.equal(resAdmin.statusCode, 200);
    } finally {
      await app.close();
    }
  });

  it('denies admin route to reader key with 403 FORBIDDEN, allows admin key with 200', async () => {
    const { app, config } = await createTestApp();
    try {
      // Reader key trying admin route
      const resForbidden = await app.inject({
        method: 'POST',
        url: '/test/admin-protected',
        headers: {
          'x-api-key': config.backendApiKey,
        },
      });
      assert.equal(resForbidden.statusCode, 403);
      const jsonForbidden = JSON.parse(resForbidden.payload);
      assert.equal(jsonForbidden.error.code, 'FORBIDDEN');
      assert.equal(jsonForbidden.error.retryable, false);

      // Admin key on admin route
      const resAllowed = await app.inject({
        method: 'POST',
        url: '/test/admin-protected',
        headers: {
          'x-api-key': config.adminApiKey,
        },
      });
      assert.equal(resAllowed.statusCode, 200);
    } finally {
      await app.close();
    }
  });

  it('returns 400 for malformed JSON and 413 for oversized body (>64 KiB)', async () => {
    const { app, config } = await createTestApp();
    try {
      // Malformed JSON
      const resMalformed = await app.inject({
        method: 'POST',
        url: '/test/body-echo',
        headers: {
          'content-type': 'application/json',
          'x-api-key': config.backendApiKey,
        },
        payload: '{ "brokenJson": true, ',
      });
      assert.equal(resMalformed.statusCode, 400);
      const jsonMalformed = JSON.parse(resMalformed.payload);
      assert.equal(jsonMalformed.error.code, 'INVALID_JSON');
      assert.equal(jsonMalformed.error.retryable, false);

      // Oversized JSON (>65536 bytes)
      const hugeString = 'a'.repeat(70000);
      const resHuge = await app.inject({
        method: 'POST',
        url: '/test/body-echo',
        headers: {
          'content-type': 'application/json',
          'x-api-key': config.backendApiKey,
        },
        payload: JSON.stringify({ data: hugeString }),
      });
      assert.equal(resHuge.statusCode, 413);
      const jsonHuge = JSON.parse(resHuge.payload);
      assert.equal(jsonHuge.error.code, 'PAYLOAD_TOO_LARGE');
    } finally {
      await app.close();
    }
  });

  it('enforces rate limiting when request limit is exceeded', async () => {
    // Configure rate limit of 2 requests per minute
    const { app, config } = await createTestApp({ rateLimitMaxPerMinute: 2 });
    try {
      const headers = { 'x-api-key': config.backendApiKey };

      const res1 = await app.inject({ method: 'GET', url: '/test/reader-protected', headers });
      assert.equal(res1.statusCode, 200);

      const res2 = await app.inject({ method: 'GET', url: '/test/reader-protected', headers });
      assert.equal(res2.statusCode, 200);

      const res3 = await app.inject({ method: 'GET', url: '/test/reader-protected', headers });
      assert.equal(res3.statusCode, 429);
      const json3 = JSON.parse(res3.payload);
      assert.equal(json3.error.code, 'RATE_LIMIT_EXCEEDED');
      assert.equal(json3.error.retryable, true);
    } finally {
      await app.close();
    }
  });

  it('ensures logs never leak API keys, authorization headers, query params or secrets', async () => {
    const { app, capturedLogs, config } = await createTestApp();
    try {
      await app.inject({
        method: 'GET',
        url: '/test/reader-protected?secretQueryToken=superSecret123&coords=10.7,106.6',
        headers: {
          'x-api-key': config.backendApiKey,
          authorization: 'Bearer superSecretTokenHeader',
        },
      });

      const joinedLogs = capturedLogs.join('\n');
      assert.doesNotMatch(joinedLogs, new RegExp(config.backendApiKey));
      assert.doesNotMatch(joinedLogs, new RegExp(config.adminApiKey));
      assert.doesNotMatch(joinedLogs, /superSecret123/);
      assert.doesNotMatch(joinedLogs, /superSecretTokenHeader/);
      assert.doesNotMatch(joinedLogs, /coords/);
    } finally {
      await app.close();
    }
  });
});
