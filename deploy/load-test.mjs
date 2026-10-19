#!/usr/bin/env node
// T08 / T06-D7: small load check for the trial backend.
// Simulates N concurrent viewers, each polling one camera snapshot every
// 12 s (the app's preview cadence) plus a catalog list call per viewer at
// the start. Reports latency percentiles and error counts.
//
// Pass criteria (T06-D7): at 20 concurrent viewers, p95 of snapshot
// responses < 500 ms and no 5xx. Exit code is non-zero when a criterion
// fails, so the run can gate a rollout decision.
//
// Usage:
//   BACKEND_URL=https://api.example.com READER_KEY=<key> node load-test.mjs
// Optional: VIEWERS=20 DURATION_S=120 POLL_MS=12000 P95_LIMIT_MS=500
//
// No dependencies (Node 18+ global fetch). The reader key is read from the
// environment only and is never printed.

const baseUrl = (process.env.BACKEND_URL || '').replace(/\/$/, '');
const readerKey = process.env.READER_KEY || '';
const viewers = Number(process.env.VIEWERS || 20);
const durationS = Number(process.env.DURATION_S || 120);
const pollMs = Number(process.env.POLL_MS || 12000);
const p95LimitMs = Number(process.env.P95_LIMIT_MS || 500);

if (!baseUrl || !readerKey) {
  console.error('BACKEND_URL and READER_KEY are required.');
  process.exit(2);
}

const headers = { 'x-api-key': readerKey };
const snapshotLatencies = [];
let ok = 0;
let notModified = 0;
let rateLimited = 0;
let clientErrors = 0;
let serverErrors = 0;
let networkErrors = 0;

async function timedFetch(url, etag) {
  const started = performance.now();
  try {
    const res = await fetch(url, {
      headers: etag ? { ...headers, 'if-none-match': etag } : headers,
    });
    const elapsed = performance.now() - started;
    await res.arrayBuffer(); // drain the body so timings include transfer
    return { res, elapsed };
  } catch (err) {
    networkErrors += 1;
    return { res: null, elapsed: performance.now() - started, err };
  }
}

function percentile(values, p) {
  if (values.length === 0) return NaN;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))];
}

async function main() {
  // Pick the first snapshot-capable camera from the real catalog.
  const listRes = await fetch(`${baseUrl}/v1/cameras?limit=50`, { headers });
  if (!listRes.ok) {
    console.error(`Catalog list failed: HTTP ${listRes.status}. Is READER_KEY valid?`);
    process.exit(2);
  }
  const listJson = await listRes.json();
  const items = listJson.data?.items || listJson.data || [];
  const camera = items.find((c) => c.snapshotCapable) || items[0];
  if (!camera) {
    console.error('Catalog is empty; run the import/sync first.');
    process.exit(2);
  }
  console.log(`Load target: camera ${camera.id} (${camera.name || 'unnamed'})`);
  console.log(`Simulating ${viewers} viewers for ${durationS}s, poll every ${pollMs}ms...`);

  const deadline = Date.now() + durationS * 1000;

  async function viewer() {
    let etag;
    while (Date.now() < deadline) {
      const { res, elapsed } = await timedFetch(
        `${baseUrl}/v1/cameras/${camera.id}/snapshot`,
        etag,
      );
      if (res) {
        snapshotLatencies.push(elapsed);
        if (res.status === 200) {
          ok += 1;
          etag = res.headers.get('etag') || etag;
        } else if (res.status === 304) {
          notModified += 1;
        } else if (res.status === 429) {
          rateLimited += 1;
        } else if (res.status >= 500) {
          serverErrors += 1;
        } else {
          clientErrors += 1;
        }
      }
      const remaining = pollMs - elapsed;
      if (remaining > 0) await new Promise((r) => setTimeout(r, remaining));
    }
  }

  await Promise.all(Array.from({ length: viewers }, viewer));

  const p50 = percentile(snapshotLatencies, 50);
  const p95 = percentile(snapshotLatencies, 95);
  const p99 = percentile(snapshotLatencies, 99);
  console.log('--- Result ---');
  console.log(`Requests: ${snapshotLatencies.length} (200: ${ok}, 304: ${notModified}, 429: ${rateLimited}, 4xx: ${clientErrors}, 5xx: ${serverErrors}, network errors: ${networkErrors})`);
  console.log(`Snapshot latency ms: p50=${p50.toFixed(0)} p95=${p95.toFixed(0)} p99=${p99.toFixed(0)}`);

  const p95Pass = p95 < p95LimitMs;
  const serverPass = serverErrors === 0 && networkErrors === 0;
  console.log(`p95 < ${p95LimitMs} ms: ${p95Pass ? 'PASS' : 'FAIL'}`);
  console.log(`No 5xx / network errors: ${serverPass ? 'PASS' : 'FAIL'}`);
  if (rateLimited > 0) {
    console.log(`Note: ${rateLimited} responses were 429 - if these are not expected at ${viewers} viewers, review RATE_LIMIT_MAX_PER_MINUTE (counted per key+IP; this test shares one IP).`);
  }
  process.exit(p95Pass && serverPass ? 0 : 1);
}

main().catch((err) => {
  console.error('Load test aborted:', err);
  process.exit(2);
});
