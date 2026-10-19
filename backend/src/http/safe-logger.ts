import { LoggerService } from '@nestjs/common';

export interface StructuredLogPayload {
  method: string;
  route: string;
  status: number;
  durationMs: number;
  requestId: string;
  providerCode?: string;
}

export class SafeLogger implements LoggerService {
  log(message: any, ...optionalParams: any[]) {
    this.safePrint('INFO', message, optionalParams);
  }

  error(message: any, ...optionalParams: any[]) {
    this.safePrint('ERROR', message, optionalParams);
  }

  warn(message: any, ...optionalParams: any[]) {
    this.safePrint('WARN', message, optionalParams);
  }

  debug(message: any, ...optionalParams: any[]) {
    this.safePrint('DEBUG', message, optionalParams);
  }

  verbose(message: any, ...optionalParams: any[]) {
    this.safePrint('VERBOSE', message, optionalParams);
  }

  private safePrint(level: string, message: any, params: any[]) {
    if (message instanceof Error) {
      console.error(`[${level}] ${message.message}\n${message.stack}`);
      return;
    }

    if (typeof message === 'object' && message !== null) {
      // Structured allowlist log
      const safe: Record<string, any> = {
        level,
        method: message.method,
        route: message.route,
        status: message.status,
        durationMs: message.durationMs,
        requestId: message.requestId,
      };
      if (message.providerCode) {
        safe.providerCode = message.providerCode;
      }
      console.log(JSON.stringify(safe));
      return;
    }

    const sanitizedMessage = this.sanitizeString(String(message));
    console.log(`[${level}] ${sanitizedMessage}`);
  }

  public sanitizeString(str: string): string {
    return str
      .replace(/x-api-key:[^\s,]+/gi, 'x-api-key:[REDACTED]')
      .replace(/Bearer\s+[a-zA-Z0-9._-]+/gi, 'Bearer [REDACTED]')
      .replace(/(?:key|token|secret|password)=[^\s&]+/gi, '$1=[REDACTED]')
      .replace(/coords=[^\s&]+/gi, 'coords=[REDACTED]');
  }
}
