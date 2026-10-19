import { z } from 'zod';

export interface AppConfig {
  port: number;
  host: string;
  databaseUrl: string;
  databaseSchema?: string;
  backendApiKey: string;
  adminApiKey: string;
  backendApiKeyPrevious?: string;
  cameraProviderMode: 'notis' | 'fixture';
  notisAuthToken?: string;
  bodyLimitBytes: number;
  snapshotMaxBytes: number;
  snapshotCacheMaxBytes: number;
  snapshotTtlMs: number;
  upstreamTimeoutMs: number;
  maxConcurrentUpstreamFetches: number;
  maxQueuedUpstreamFetches: number;
  rateLimitMaxPerMinute: number;
  catalogStaleAfterMs: number;
  defaultRefreshIntervalMs: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const schema = z.object({
    PORT: z.string().optional().default('3000').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1 || n > 65535) {
        throw new Error('PORT must be an integer between 1 and 65535');
      }
      return n;
    }),
    HOST: z.string().optional().default('127.0.0.1'),
    DATABASE_URL: z.string({
      error: 'DATABASE_URL is required',
    }).min(1, 'DATABASE_URL is required'),
    BACKEND_API_KEY: z.string({
      error: 'BACKEND_API_KEY is required',
    }).min(1, 'BACKEND_API_KEY is required'),
    ADMIN_API_KEY: z.string({
      error: 'ADMIN_API_KEY is required',
    }).min(1, 'ADMIN_API_KEY is required'),
    BACKEND_API_KEY_PREVIOUS: z.string().min(1, 'BACKEND_API_KEY_PREVIOUS must not be empty').optional(),
    CAMERA_PROVIDER_MODE: z.enum(['notis', 'fixture'], {
      error: 'CAMERA_PROVIDER_MODE must be either "notis" or "fixture"',
    }).default('notis'),
    NOTIS_AUTH_TOKEN: z.string().optional(),
    BODY_LIMIT_BYTES: z.string().optional().default('65536').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1024) throw new Error('BODY_LIMIT_BYTES must be at least 1024');
      return n;
    }),
    SNAPSHOT_MAX_BYTES: z.string().optional().default('2097152').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1024) throw new Error('SNAPSHOT_MAX_BYTES must be at least 1024');
      return n;
    }),
    SNAPSHOT_CACHE_MAX_BYTES: z.string().optional().default('33554432').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1048576) throw new Error('SNAPSHOT_CACHE_MAX_BYTES must be at least 1048576');
      return n;
    }),
    SNAPSHOT_TTL_MS: z.string().optional().default('3000').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 100) throw new Error('SNAPSHOT_TTL_MS must be at least 100');
      return n;
    }),
    UPSTREAM_TIMEOUT_MS: z.string().optional().default('5000').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 100) throw new Error('UPSTREAM_TIMEOUT_MS must be at least 100');
      return n;
    }),
    MAX_CONCURRENT_UPSTREAM_FETCHES: z.string().optional().default('4').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1) throw new Error('MAX_CONCURRENT_UPSTREAM_FETCHES must be at least 1');
      return n;
    }),
    MAX_QUEUED_UPSTREAM_FETCHES: z.string().optional().default('32').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1) throw new Error('MAX_QUEUED_UPSTREAM_FETCHES must be at least 1');
      return n;
    }),
    RATE_LIMIT_MAX_PER_MINUTE: z.string().optional().default('120').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1) throw new Error('RATE_LIMIT_MAX_PER_MINUTE must be at least 1');
      return n;
    }),
    CATALOG_STALE_AFTER_MS: z.string().optional().default('86400000').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1000) throw new Error('CATALOG_STALE_AFTER_MS must be at least 1000');
      return n;
    }),
    DEFAULT_REFRESH_INTERVAL_MS: z.string().optional().default('12000').transform((v) => {
      const n = parseInt(v, 10);
      if (isNaN(n) || n < 1000) throw new Error('DEFAULT_REFRESH_INTERVAL_MS must be at least 1000');
      return n;
    }),
  });

  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const errorDetails = parsed.error.issues
      .map((i) => `${i.path.join('.')}: ${i.message}`)
      .join(', ');
    throw new Error(`Configuration validation failed: ${errorDetails}`);
  }

  const data = parsed.data;

  // Validate that ADMIN_API_KEY and BACKEND_API_KEY are not identical
  if (data.ADMIN_API_KEY === data.BACKEND_API_KEY) {
    throw new Error('Configuration validation failed: ADMIN_API_KEY and BACKEND_API_KEY must not be identical');
  }

  // The rotation-window previous reader key must be a distinct credential:
  // equal to the current key it would be a no-op, equal to the admin key it
  // would silently hand admin rights to every app build (T06-D3).
  if (
    data.BACKEND_API_KEY_PREVIOUS !== undefined &&
    (data.BACKEND_API_KEY_PREVIOUS === data.BACKEND_API_KEY ||
      data.BACKEND_API_KEY_PREVIOUS === data.ADMIN_API_KEY)
  ) {
    throw new Error(
      'Configuration validation failed: BACKEND_API_KEY_PREVIOUS must not be identical to BACKEND_API_KEY or ADMIN_API_KEY',
    );
  }

  return {
    port: data.PORT,
    host: data.HOST,
    databaseUrl: data.DATABASE_URL,
    backendApiKey: data.BACKEND_API_KEY,
    adminApiKey: data.ADMIN_API_KEY,
    backendApiKeyPrevious: data.BACKEND_API_KEY_PREVIOUS,
    cameraProviderMode: data.CAMERA_PROVIDER_MODE,
    notisAuthToken: data.NOTIS_AUTH_TOKEN,
    bodyLimitBytes: data.BODY_LIMIT_BYTES,
    snapshotMaxBytes: data.SNAPSHOT_MAX_BYTES,
    snapshotCacheMaxBytes: data.SNAPSHOT_CACHE_MAX_BYTES,
    snapshotTtlMs: data.SNAPSHOT_TTL_MS,
    upstreamTimeoutMs: data.UPSTREAM_TIMEOUT_MS,
    maxConcurrentUpstreamFetches: data.MAX_CONCURRENT_UPSTREAM_FETCHES,
    maxQueuedUpstreamFetches: data.MAX_QUEUED_UPSTREAM_FETCHES,
    rateLimitMaxPerMinute: data.RATE_LIMIT_MAX_PER_MINUTE,
    catalogStaleAfterMs: data.CATALOG_STALE_AFTER_MS,
    defaultRefreshIntervalMs: data.DEFAULT_REFRESH_INTERVAL_MS,
  };
}
