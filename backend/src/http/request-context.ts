import crypto from 'node:crypto';

export const CLOCK = 'CLOCK';

export interface Clock {
  now(): number;
  nowDate(): Date;
}

export class SystemClock implements Clock {
  now(): number {
    return Date.now();
  }

  nowDate(): Date {
    return new Date();
  }
}

const SAFE_REQUEST_ID_REGEX = /^[a-zA-Z0-9_-]{1,128}$/;

export function sanitizeOrGenerateRequestId(incomingId?: string | string[]): string {
  if (typeof incomingId === 'string' && SAFE_REQUEST_ID_REGEX.test(incomingId)) {
    return incomingId;
  }
  return crypto.randomUUID();
}
