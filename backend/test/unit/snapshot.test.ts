import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { detectImageMime } from '../../src/snapshot/mime.js';
import { BoundedCache } from '../../src/snapshot/bounded-cache.js';
import { FetchPool } from '../../src/snapshot/fetch-pool.js';
import { FakeClock } from '../helpers/clock.js';
import { ApiError } from '../../src/http/api-error.js';

describe('Snapshot Pipeline Utilities (Unit)', () => {
  describe('MIME detection from magic bytes', () => {
    it('detects JPEG, PNG, WebP and rejects HTML/JSON/garbage', () => {
      const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
      assert.equal(detectImageMime(jpeg), 'image/jpeg');

      const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      assert.equal(detectImageMime(png), 'image/png');

      const webp = Buffer.from([
        0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);
      assert.equal(detectImageMime(webp), 'image/webp');

      const html = Buffer.from('<!DOCTYPE html><html><body>Error</body></html>');
      assert.equal(detectImageMime(html), null);

      const json = Buffer.from('{"error":"not found"}');
      assert.equal(detectImageMime(json), null);

      assert.equal(detectImageMime(Buffer.alloc(0)), null);
    });
  });

  describe('BoundedCache', () => {
    it('enforces TTL using injected Clock', () => {
      const clock = new FakeClock(1000);
      const cache = new BoundedCache({
        maxSizeBytes: 1024 * 1024,
        maxItemBytes: 64 * 1024,
        ttlMs: 3000,
        clock,
      });

      const bytes = Buffer.from('image_bytes_123');
      cache.set('cam_1', {
        bytes,
        mime: 'image/png',
        etag: '"test_etag"',
        fetchedAt: clock.nowDate(),
      });

      // Advance by 2999ms -> still valid
      clock.advance(2999);
      const hit = cache.get('cam_1');
      assert.ok(hit);
      assert.equal(hit.etag, '"test_etag"');

      // Advance by 2ms (total 3001ms) -> expired
      clock.advance(2);
      const miss = cache.get('cam_1');
      assert.equal(miss, null);
    });

    it('enforces byte budget and evicts least recently used items', () => {
      const clock = new FakeClock(1000);
      const cache = new BoundedCache({
        maxSizeBytes: 100, // tiny budget
        maxItemBytes: 60,
        ttlMs: 10000,
        clock,
      });

      const buf40 = Buffer.alloc(40);
      cache.set('item_1', { bytes: buf40, mime: 'image/png', etag: '"e1"', fetchedAt: clock.nowDate() });
      cache.set('item_2', { bytes: buf40, mime: 'image/png', etag: '"e2"', fetchedAt: clock.nowDate() });

      assert.ok(cache.get('item_1'));
      assert.ok(cache.get('item_2'));

      // Adding item_3 (40 bytes) exceeds 100 total budget -> evicts LRU (item_1 was accessed before item_2, so item_1 is oldest accessed if we access item_2 now)
      cache.get('item_2'); // access item_2 to make item_1 oldest
      cache.set('item_3', { bytes: buf40, mime: 'image/png', etag: '"e3"', fetchedAt: clock.nowDate() });

      assert.equal(cache.get('item_1'), null, 'item_1 should have been evicted');
      assert.ok(cache.get('item_2'));
      assert.ok(cache.get('item_3'));
    });

    it('refuses to cache items larger than maxItemBytes', () => {
      const clock = new FakeClock();
      const cache = new BoundedCache({
        maxSizeBytes: 1000,
        maxItemBytes: 50,
        ttlMs: 5000,
        clock,
      });

      const oversized = Buffer.alloc(60);
      cache.set('huge', { bytes: oversized, mime: 'image/png', etag: '"huge"', fetchedAt: clock.nowDate() });
      assert.equal(cache.get('huge'), null);
    });
  });

  describe('FetchPool', () => {
    it('allows up to maxActive concurrently and queues waiters, rejecting when queue is full', async () => {
      const pool = new FetchPool({ maxActive: 2, maxQueued: 2 });

      const release1 = await pool.acquire();
      const release2 = await pool.acquire();

      let waiter1Done = false;
      const waiter1 = pool.acquire().then((rel: () => void) => {
        waiter1Done = true;
        return rel;
      });

      let waiter2Done = false;
      const waiter2 = pool.acquire().then((rel: () => void) => {
        waiter2Done = true;
        return rel;
      });

      // 5th request exceeds maxQueued (2 active + 2 queued) -> throws 503 BUSY
      await assert.rejects(
        () => pool.acquire(),
        (err: ApiError) => {
          assert.equal(err.code, 'BUSY');
          assert.equal(err.status, 503);
          return true;
        }
      );

      assert.equal(waiter1Done, false);
      release1();
      const releaseW1 = await waiter1;
      assert.equal(waiter1Done, true);

      release2();
      const releaseW2 = await waiter2;
      assert.equal(waiter2Done, true);

      releaseW1();
      releaseW2();
    });

    it('aborts queued waiter cleanly when its signal is cancelled without leaking slots', async () => {
      const pool = new FetchPool({ maxActive: 1, maxQueued: 5 });

      const releaseActive = await pool.acquire();

      const controller = new AbortController();
      const waiterPromise = pool.acquire(controller.signal);

      // Abort queued waiter
      controller.abort();

      await assert.rejects(waiterPromise, (err: any) => {
        assert.equal(err.name, 'AbortError');
        return true;
      });

      releaseActive();

      // Ensure next acquire works immediately
      const nextRelease = await pool.acquire();
      assert.ok(nextRelease);
      nextRelease();
    });
  });
});
