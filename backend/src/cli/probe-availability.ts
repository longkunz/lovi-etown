import dotenv from 'dotenv';
import { loadConfig } from '../config/config.js';
import { createDatabasePool } from '../database/pool.js';
import { PgCatalogRepository } from '../catalog/catalog.repository.js';
import { NotisProvider } from '../providers/notis.provider.js';
import { FixtureProvider } from '../providers/fixture.provider.js';
import { AvailabilityProber } from '../notifications/availability-prober.js';
import { loadFcmSenderFromEnv } from '../notifications/fcm-sender.js';

dotenv.config();

/**
 * One availability probe pass (T16). Intended to run on a schedule
 * (e.g. every few minutes from cron on the VPS) once the trial wants
 * per-camera notifications. Without FCM_SERVICE_ACCOUNT_JSON it only
 * maintains availability state and reports the changes it found.
 */
async function main() {
  const config = loadConfig(process.env);
  const pool = createDatabasePool(config);
  try {
    const repo = new PgCatalogRepository(pool, undefined, undefined, config.catalogStaleAfterMs);
    const provider =
      config.cameraProviderMode === 'fixture'
        ? new FixtureProvider()
        : new NotisProvider({
            authToken: config.notisAuthToken,
            timeoutMs: config.upstreamTimeoutMs,
          });
    const sender = loadFcmSenderFromEnv(process.env);
    const prober = new AvailabilityProber({ repository: repo, provider, sender });

    const summary = await prober.runOnce('tp_hcm');
    console.log(
      `Availability probe: checked=${summary.checked}, online=${summary.online}, offline=${summary.offline}, changes=${summary.changes}, notified=${summary.notified}` +
        (sender ? '' : ' (notifications disabled: FCM_SERVICE_ACCOUNT_JSON not set)')
    );
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error(`Availability probe failed: ${err.message}`);
  process.exit(1);
});
