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

export class FakeClock implements Clock {
  private current: number;

  constructor(initialMs: number = 1773489600000) {
    this.current = initialMs;
  }

  now(): number {
    return this.current;
  }

  nowDate(): Date {
    return new Date(this.current);
  }

  advance(ms: number): void {
    this.current += ms;
  }

  set(ms: number): void {
    this.current = ms;
  }
}
