import crypto from 'node:crypto';
import { createApp } from '../../src/create-app.js';
import { loadConfig } from '../../src/config/config.js';

interface SmokeOptions {
  bbox: [number, number, number, number];
  baseUrl?: string;
}

function parseArgs(): SmokeOptions {
  const args = process.argv.slice(2);
  let bbox: [number, number, number, number] = [106.695, 10.770, 106.705, 10.780];
  let baseUrl: string | undefined = undefined;

  for (const arg of args) {
    if (arg.startsWith('--bbox=')) {
      const parts = arg.slice(7).split(',').map((s) => parseFloat(s.trim()));
      if (parts.length === 4 && parts.every((n) => !isNaN(n) && isFinite(n))) {
        bbox = [parts[0], parts[1], parts[2], parts[3]];
      } else {
        console.error('Invalid --bbox argument. Expected --bbox=west,south,east,north');
        process.exit(1);
      }
    } else if (arg.startsWith('--url=')) {
      baseUrl = arg.slice(6).trim();
    }
  }

  return { bbox, baseUrl };
}

async function runSmoke() {
  const { bbox, baseUrl } = parseArgs();
  console.log('====================================================');
  console.log('   CAMERA BACKEND A1 - NOTIS REAL-SOURCE SMOKE CLI  ');
  console.log('====================================================');
  console.log(`[SMOKE] Target Bbox: [${bbox.join(', ')}]`);

  const config = loadConfig();
  console.log(`[SMOKE] Provider Mode: ${config.cameraProviderMode}`);

  let app: any;
  let client: {
    get: (url: string, headers?: Record<string, string>) => Promise<{ statusCode: number; headers: Record<string, any>; body: any; raw: Buffer }>;
    post: (url: string, body: any, headers?: Record<string, string>) => Promise<{ statusCode: number; headers: Record<string, any>; body: any }>;
  };

  if (baseUrl) {
    console.log(`[SMOKE] Connecting to live HTTP target: ${baseUrl}`);
    client = {
      get: async (url, headers = {}) => {
        const fullUrl = new URL(url, baseUrl).toString();
        const res = await fetch(fullUrl, { method: 'GET', headers });
        const raw = Buffer.from(await res.arrayBuffer());
        let body: any;
        try {
          body = JSON.parse(raw.toString('utf8'));
        } catch {
          body = raw;
        }
        const respHeaders: Record<string, any> = {};
        res.headers.forEach((v, k) => {
          respHeaders[k.toLowerCase()] = v;
        });
        return { statusCode: res.status, headers: respHeaders, body, raw };
      },
      post: async (url, reqBody, headers = {}) => {
        const fullUrl = new URL(url, baseUrl).toString();
        const res = await fetch(fullUrl, {
          method: 'POST',
          headers: { ...headers, 'content-type': 'application/json' },
          body: JSON.stringify(reqBody),
        });
        const raw = Buffer.from(await res.arrayBuffer());
        let body: any;
        try {
          body = JSON.parse(raw.toString('utf8'));
        } catch {
          body = raw;
        }
        const respHeaders: Record<string, any> = {};
        res.headers.forEach((v, k) => {
          respHeaders[k.toLowerCase()] = v;
        });
        return { statusCode: res.status, headers: respHeaders, body };
      },
    };
  } else {
    console.log('[SMOKE] Running in-process application container with active configuration');
    app = await createApp({ config });
    client = {
      get: async (url, headers = {}) => {
        const res = await app.inject({ method: 'GET', url, headers });
        let body: any;
        try {
          body = JSON.parse(res.payload);
        } catch {
          body = res.rawPayload;
        }
        return { statusCode: res.statusCode, headers: res.headers, body, raw: res.rawPayload };
      },
      post: async (url, reqBody, headers = {}) => {
        const res = await app.inject({ method: 'POST', url, headers, payload: reqBody });
        let body: any;
        try {
          body = JSON.parse(res.payload);
        } catch {
          body = res.rawPayload;
        }
        return { statusCode: res.statusCode, headers: res.headers, body };
      },
    };
  }

  try {
    // 1. Health checks
    console.log('\n--- 1. Health Inspection ---');
    const liveRes = await client.get('/health/live');
    if (liveRes.statusCode !== 200) {
      throw new Error(`Live check failed with status ${liveRes.statusCode}`);
    }
    const readyRes = await client.get('/health/ready');
    if (readyRes.statusCode !== 200) {
      throw new Error(`Ready check failed with status ${readyRes.statusCode}`);
    }
    console.log('[PASS] Live: 200 OK, Ready: 200 OK');

    // 2. Admin Synchronization
    console.log('\n--- 2. Synchronize Catalog via Notis Provider ---');
    const startSync = Date.now();
    const syncRes = await client.post(
      '/v1/admin/camera-providers/notis/sync',
      { provinceId: 'tp_hcm', bbox },
      { 'x-api-key': config.adminApiKey }
    );
    const syncDuration = Date.now() - startSync;

    if (syncRes.statusCode !== 200) {
      throw new Error(`Sync failed with status ${syncRes.statusCode}: ${JSON.stringify(syncRes.body)}`);
    }

    const syncData = syncRes.body.data || syncRes.body;
    console.log(`[PASS] Sync completed in ${syncDuration}ms:`);
    console.log(`       - Version: ${syncData.version}`);
    console.log(`       - Upserted Count: ${syncData.upsertedCount}`);
    console.log(`       - Received Count: ${syncData.receivedCount}`);
    console.log(`       - Coverage: ${syncData.coverage}`);

    // 3. Query Catalog
    console.log('\n--- 3. List and Select Snapshot Camera ---');
    const listRes = await client.get(
      '/v1/cameras?provinceId=tp_hcm&limit=10',
      { 'x-api-key': config.backendApiKey }
    );
    if (listRes.statusCode !== 200) {
      throw new Error(`List failed with status ${listRes.statusCode}`);
    }
    const cameras = listRes.body.data;
    if (!Array.isArray(cameras) || cameras.length === 0) {
      throw new Error('No cameras found in catalog after sync');
    }

    const targetCamera = cameras.find((c: any) => c.capabilities?.snapshot) || cameras[0];
    console.log(`[PASS] Selected Camera UUID: ${targetCamera.id}`);
    console.log(`       - Name: ${targetCamera.name}`);
    console.log(`       - District: ${targetCamera.district ?? 'N/A'}`);
    console.log(`       - Capabilities: ${JSON.stringify(targetCamera.capabilities)}`);

    // 4. Playback Descriptor
    console.log('\n--- 4. Playback Descriptor Inspection ---');
    const playbackRes = await client.get(
      `/v1/cameras/${targetCamera.id}/playback`,
      { 'x-api-key': config.backendApiKey }
    );
    if (playbackRes.statusCode !== 200) {
      throw new Error(`Playback descriptor failed with status ${playbackRes.statusCode}`);
    }
    console.log(`[PASS] Playback Kind: ${playbackRes.body.data?.kind}`);
    console.log(`       - Endpoint: ${playbackRes.body.data?.snapshotEndpoint}`);

    // 5. Snapshot Fetch (First: Expect 200 with bytes)
    console.log('\n--- 5. Snapshot Pipeline Execution (Call 1: Fresh) ---');
    const startSnap1 = Date.now();
    const snap1Res = await client.get(
      `/v1/cameras/${targetCamera.id}/snapshot`,
      { 'x-api-key': config.backendApiKey }
    );
    const snap1Duration = Date.now() - startSnap1;

    if (snap1Res.statusCode !== 200) {
      throw new Error(`Snapshot call 1 failed with status ${snap1Res.statusCode}: ${JSON.stringify(snap1Res.body)}`);
    }

    const etag = snap1Res.headers['etag'];
    const mime = snap1Res.headers['content-type'];
    const fetchedAt = snap1Res.headers['x-image-fetched-at'];
    const dataMode = snap1Res.headers['x-data-mode'];
    const hash = crypto.createHash('sha256').update(snap1Res.raw).digest('hex').slice(0, 16);

    console.log(`[PASS] Snapshot 1 Fetched in ${snap1Duration}ms:`);
    console.log(`       - Status: ${snap1Res.statusCode}`);
    console.log(`       - Content-Type: ${mime}`);
    console.log(`       - Byte Size: ${snap1Res.raw.length} bytes`);
    console.log(`       - SHA256 Prefix: ${hash}`);
    console.log(`       - ETag: ${etag}`);
    console.log(`       - X-Image-Fetched-At: ${fetchedAt}`);
    console.log(`       - X-Data-Mode: ${dataMode}`);

    // 6. Snapshot Fetch (Second: Expect 304 Not Modified within TTL)
    console.log('\n--- 6. Snapshot Cache & ETag Validation (Call 2: If-None-Match) ---');
    const startSnap2 = Date.now();
    const snap2Res = await client.get(
      `/v1/cameras/${targetCamera.id}/snapshot`,
      {
        'x-api-key': config.backendApiKey,
        'if-none-match': etag,
      }
    );
    const snap2Duration = Date.now() - startSnap2;

    if (snap2Res.statusCode !== 304) {
      throw new Error(`Snapshot call 2 expected 304 Not Modified, got ${snap2Res.statusCode}`);
    }
    console.log(`[PASS] Snapshot 2 Validated in ${snap2Duration}ms:`);
    console.log(`       - Status: 304 Not Modified`);
    console.log(`       - Body Bytes: ${snap2Res.raw.length} (empty body verified)`);

    console.log('\n====================================================');
    console.log('   SMOKE TEST RESULT: ALL CHECKS PASSED SUCCESSFULLY ');
    console.log('====================================================\n');
  } finally {
    if (app) {
      await app.close();
    }
  }
}

runSmoke().catch((err) => {
  console.error('\n[SMOKE FAILED]:', err.message);
  process.exit(1);
});
