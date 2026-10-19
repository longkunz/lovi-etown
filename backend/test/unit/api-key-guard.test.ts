import 'reflect-metadata';
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { ExecutionContext } from '@nestjs/common';
import { ApiKeyGuard, IS_PUBLIC_KEY } from '../../src/http/api-key.guard.js';
import { IS_ADMIN_ONLY_KEY } from '../../src/http/admin-only.decorator.js';
import { ApiError } from '../../src/http/api-error.js';
import { AppConfig } from '../../src/config/config.js';

// T07 / T06-D3: during a key rotation the backend accepts the previous
// reader key alongside the current one (the overlap window). The previous
// key is a reader credential only: it must never open admin routes.

const baseConfig = {
  backendApiKey: 'reader-current',
  adminApiKey: 'admin-secret',
  backendApiKeyPrevious: 'reader-previous',
} as unknown as AppConfig;

function makeGuard(config: AppConfig, adminOnly: boolean): ApiKeyGuard {
  const reflector = {
    getAllAndOverride: (key: string) => {
      if (key === IS_PUBLIC_KEY) return false;
      if (key === IS_ADMIN_ONLY_KEY) return adminOnly;
      return undefined;
    },
  };
  return new ApiKeyGuard(reflector as never, config);
}

function makeContext(apiKey?: string): ExecutionContext {
  return {
    getHandler: () => ({}),
    getClass: () => ({}),
    switchToHttp: () => ({
      getRequest: () => ({
        headers: apiKey === undefined ? {} : { 'x-api-key': apiKey },
      }),
    }),
  } as unknown as ExecutionContext;
}

function assertApiError(fn: () => unknown, status: number, code: string) {
  assert.throws(fn, (err: unknown) => {
    assert.ok(err instanceof ApiError, `expected ApiError, got ${err}`);
    assert.equal((err as ApiError).status, status);
    assert.equal((err as ApiError).code, code);
    return true;
  });
}

describe('ApiKeyGuard reader routes (Unit)', () => {
  const guard = () => makeGuard(baseConfig, false);

  it('accepts the current reader key', () => {
    assert.equal(guard().canActivate(makeContext('reader-current')), true);
  });

  it('accepts the previous reader key during the rotation window', () => {
    assert.equal(guard().canActivate(makeContext('reader-previous')), true);
  });

  it('accepts the admin key on reader routes', () => {
    assert.equal(guard().canActivate(makeContext('admin-secret')), true);
  });

  it('rejects an unknown key with 401 UNAUTHORIZED', () => {
    assertApiError(() => guard().canActivate(makeContext('nope')), 401, 'UNAUTHORIZED');
  });

  it('rejects a missing key with 401 UNAUTHORIZED', () => {
    assertApiError(() => guard().canActivate(makeContext(undefined)), 401, 'UNAUTHORIZED');
  });

  it('rejects the previous key once it is no longer configured', () => {
    const noPrevious = { ...baseConfig, backendApiKeyPrevious: undefined } as unknown as AppConfig;
    assertApiError(
      () => makeGuard(noPrevious, false).canActivate(makeContext('reader-previous')),
      401,
      'UNAUTHORIZED',
    );
  });
});

describe('ApiKeyGuard admin routes (Unit)', () => {
  const guard = () => makeGuard(baseConfig, true);

  it('accepts the admin key', () => {
    assert.equal(guard().canActivate(makeContext('admin-secret')), true);
  });

  it('rejects the current reader key with 403 FORBIDDEN', () => {
    assertApiError(() => guard().canActivate(makeContext('reader-current')), 403, 'FORBIDDEN');
  });

  it('rejects the previous reader key with 403 FORBIDDEN (reader credential, not admin)', () => {
    assertApiError(() => guard().canActivate(makeContext('reader-previous')), 403, 'FORBIDDEN');
  });

  it('rejects an unknown key with 401 UNAUTHORIZED', () => {
    assertApiError(() => guard().canActivate(makeContext('nope')), 401, 'UNAUTHORIZED');
  });
});
