import { ApiError } from '../http/api-error.js';

export interface FetchPoolOptions {
  maxActive?: number;
  maxQueued?: number;
}

interface QueuedWaiter {
  resolve: (release: () => void) => void;
  reject: (err: any) => void;
  signal?: AbortSignal;
  onAbort?: () => void;
}

export class FetchPool {
  private readonly maxActive: number;
  private readonly maxQueued: number;
  private activeCount = 0;
  private readonly queue: QueuedWaiter[] = [];

  constructor(options?: FetchPoolOptions) {
    this.maxActive = options?.maxActive ?? 4;
    this.maxQueued = options?.maxQueued ?? 32;
  }

  get active(): number {
    return this.activeCount;
  }

  get queued(): number {
    return this.queue.length;
  }

  async acquire(signal?: AbortSignal): Promise<() => void> {
    if (signal?.aborted) {
      const err = new Error('The operation was aborted');
      err.name = 'AbortError';
      throw err;
    }

    if (this.activeCount < this.maxActive) {
      this.activeCount++;
      return this.createRelease();
    }

    if (this.queue.length >= this.maxQueued) {
      throw new ApiError('BUSY', 503, true, 'Snapshot fetch pool queue is full');
    }

    return new Promise<() => void>((resolve, reject) => {
      const waiter: QueuedWaiter = {
        resolve,
        reject,
        signal,
      };

      if (signal) {
        const onAbort = () => {
          const idx = this.queue.indexOf(waiter);
          if (idx !== -1) {
            this.queue.splice(idx, 1);
          }
          const err = new Error('The operation was aborted');
          err.name = 'AbortError';
          reject(err);
        };
        waiter.onAbort = onAbort;
        signal.addEventListener('abort', onAbort, { once: true });
      }

      this.queue.push(waiter);
    });
  }

  private createRelease(): () => void {
    let released = false;
    return () => {
      if (released) return;
      released = true;
      this.activeCount--;
      this.processQueue();
    };
  }

  private processQueue(): void {
    while (this.queue.length > 0 && this.activeCount < this.maxActive) {
      const waiter = this.queue.shift()!;
      if (waiter.signal) {
        if (waiter.onAbort) {
          waiter.signal.removeEventListener('abort', waiter.onAbort);
        }
        if (waiter.signal.aborted) {
          continue;
        }
      }
      this.activeCount++;
      waiter.resolve(this.createRelease());
    }
  }
}
