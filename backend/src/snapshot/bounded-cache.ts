import { Clock, SystemClock } from '../http/request-context.js';

export interface CacheItem {
  bytes: Buffer;
  mime: string;
  etag: string;
  fetchedAt: Date;
}

export type CachedSnapshot = CacheItem;


interface CacheEntry extends CacheItem {
  expiresAt: number;
  byteSize: number;
}

export interface BoundedCacheOptions {
  maxSizeBytes?: number;
  maxItemBytes?: number;
  ttlMs?: number;
  clock?: Clock;
}

export class BoundedCache {
  private readonly maxSizeBytes: number;
  private readonly maxItemBytes: number;
  private readonly ttlMs: number;
  private readonly clock: Clock;
  private readonly entries = new Map<string, CacheEntry>();
  private currentTotalBytes = 0;

  constructor(options?: BoundedCacheOptions) {
    this.maxSizeBytes = options?.maxSizeBytes ?? 33554432; // 32 MiB
    this.maxItemBytes = options?.maxItemBytes ?? 2097152; // 2 MiB
    this.ttlMs = options?.ttlMs ?? 3000;
    this.clock = options?.clock ?? new SystemClock();
  }

  get(key: string): CacheItem | null {
    const entry = this.entries.get(key);
    if (!entry) {
      return null;
    }

    const now = this.clock.now();
    if (now >= entry.expiresAt) {
      this.deleteEntry(key);
      return null;
    }

    // Refresh LRU position by re-inserting
    this.entries.delete(key);
    this.entries.set(key, entry);

    return {
      bytes: entry.bytes,
      mime: entry.mime,
      etag: entry.etag,
      fetchedAt: entry.fetchedAt,
    };
  }

  set(key: string, item: CacheItem): void {
    const byteSize = item.bytes.length;
    if (byteSize > this.maxItemBytes) {
      return; // Do not cache oversized items
    }

    // Remove existing entry for same key if present
    if (this.entries.has(key)) {
      this.deleteEntry(key);
    }

    // Evict oldest items if adding this exceeds maxSizeBytes
    while (this.currentTotalBytes + byteSize > this.maxSizeBytes && this.entries.size > 0) {
      const oldestKey = this.entries.keys().next().value;
      if (oldestKey) {
        this.deleteEntry(oldestKey);
      } else {
        break;
      }
    }

    if (this.currentTotalBytes + byteSize <= this.maxSizeBytes) {
      const entry: CacheEntry = {
        ...item,
        byteSize,
        expiresAt: this.clock.now() + this.ttlMs,
      };
      this.entries.set(key, entry);
      this.currentTotalBytes += byteSize;
    }
  }

  private deleteEntry(key: string): void {
    const entry = this.entries.get(key);
    if (entry) {
      this.currentTotalBytes -= entry.byteSize;
      this.entries.delete(key);
    }
  }

  clear(): void {
    this.entries.clear();
    this.currentTotalBytes = 0;
  }
}
