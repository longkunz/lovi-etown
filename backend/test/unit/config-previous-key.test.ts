import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../../src/config/config.js';

// T07 / T06-D3: BACKEND_API_KEY_PREVIOUS is the optional rotation-window
// reader key. It must stay optional, and it must never collide with the
// current reader key or the admin key.

describe('Config previous reader key (Unit)', () => {
  const baseValidEnv: NodeJS.ProcessEnv = {
    DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:5432/camera_catalog',
    BACKEND_API_KEY: 'reader-current',
    ADMIN_API_KEY: 'admin-secret',
  };

  it('is undefined when BACKEND_API_KEY_PREVIOUS is not set', () => {
    const config = loadConfig(baseValidEnv);
    assert.equal(config.backendApiKeyPrevious, undefined);
  });

  it('loads BACKEND_API_KEY_PREVIOUS when set', () => {
    const config = loadConfig({
      ...baseValidEnv,
      BACKEND_API_KEY_PREVIOUS: 'reader-previous',
    });
    assert.equal(config.backendApiKeyPrevious, 'reader-previous');
  });

  it('rejects a previous key identical to the current reader key', () => {
    assert.throws(
      () =>
        loadConfig({
          ...baseValidEnv,
          BACKEND_API_KEY_PREVIOUS: 'reader-current',
        }),
      /BACKEND_API_KEY_PREVIOUS must not be identical/,
    );
  });

  it('rejects a previous key identical to the admin key', () => {
    assert.throws(
      () =>
        loadConfig({
          ...baseValidEnv,
          BACKEND_API_KEY_PREVIOUS: 'admin-secret',
        }),
      /BACKEND_API_KEY_PREVIOUS must not be identical/,
    );
  });

  it('rejects an empty previous key', () => {
    assert.throws(() =>
      loadConfig({
        ...baseValidEnv,
        BACKEND_API_KEY_PREVIOUS: '',
      }),
    );
  });
});
