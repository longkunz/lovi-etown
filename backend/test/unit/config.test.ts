import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../../src/config/config.js';

describe('Config Loader (Unit)', () => {
  const baseValidEnv: NodeJS.ProcessEnv = {
    DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5432/camera_catalog',
    BACKEND_API_KEY: 'test-backend-reader-key-32charslong!!',
    ADMIN_API_KEY: 'test-backend-admin-key-32charslong!!',
  };

  it('loads valid configuration with default notis mode and standard bounds', () => {
    const config = loadConfig(baseValidEnv);
    assert.equal(config.cameraProviderMode, 'notis');
    assert.equal(config.port, 3000);
    assert.equal(config.host, '127.0.0.1');
    assert.equal(config.bodyLimitBytes, 65536);
    assert.equal(config.snapshotMaxBytes, 2097152);
    assert.equal(config.snapshotCacheMaxBytes, 33554432);
    assert.equal(config.snapshotTtlMs, 3000);
    assert.equal(config.upstreamTimeoutMs, 5000);
    assert.equal(config.maxConcurrentUpstreamFetches, 4);
    assert.equal(config.maxQueuedUpstreamFetches, 32);
    assert.equal(config.rateLimitMaxPerMinute, 120);
    assert.equal(config.catalogStaleAfterMs, 86400000);
    assert.equal(config.defaultRefreshIntervalMs, 12000);
  });

  it('allows explicit override to fixture mode', () => {
    const config = loadConfig({
      ...baseValidEnv,
      CAMERA_PROVIDER_MODE: 'fixture',
    });
    assert.equal(config.cameraProviderMode, 'fixture');
  });

  it('fails when DATABASE_URL is missing', () => {
    const env = { ...baseValidEnv };
    delete env.DATABASE_URL;
    assert.throws(
      () => loadConfig(env),
      (err: Error) => {
        assert.match(err.message, /DATABASE_URL/);
        return true;
      }
    );
  });

  it('fails when BACKEND_API_KEY is missing or empty', () => {
    const env = { ...baseValidEnv, BACKEND_API_KEY: '' };
    assert.throws(
      () => loadConfig(env),
      (err: Error) => {
        assert.match(err.message, /BACKEND_API_KEY/);
        return true;
      }
    );
  });

  it('fails when ADMIN_API_KEY is identical to BACKEND_API_KEY', () => {
    const secret = 'identical-secret-value-1234567890';
    const env = {
      ...baseValidEnv,
      BACKEND_API_KEY: secret,
      ADMIN_API_KEY: secret,
    };
    assert.throws(
      () => loadConfig(env),
      (err: Error) => {
        // Assert error indicates keys cannot be identical
        assert.match(err.message, /ADMIN_API_KEY and BACKEND_API_KEY must not be identical/);
        // Assert the actual secret value is NOT echoed in the error message
        assert.doesNotMatch(err.message, new RegExp(secret));
        return true;
      }
    );
  });

  it('fails on invalid numeric bounds (e.g. negative port or limits)', () => {
    const env = { ...baseValidEnv, PORT: '-1' };
    assert.throws(
      () => loadConfig(env),
      (err: Error) => {
        assert.match(err.message, /PORT/);
        return true;
      }
    );
  });

  it('fails on invalid CAMERA_PROVIDER_MODE', () => {
    const env = { ...baseValidEnv, CAMERA_PROVIDER_MODE: 'unknown_provider' };
    assert.throws(
      () => loadConfig(env),
      (err: Error) => {
        assert.match(err.message, /CAMERA_PROVIDER_MODE/);
        return true;
      }
    );
  });
});
