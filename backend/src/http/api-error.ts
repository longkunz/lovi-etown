export class ApiError extends Error {
  public readonly code: string;
  public readonly status: number;
  public readonly retryable: boolean;
  public readonly publicMessage: string;

  constructor(code: string, status: number, retryable: boolean, publicMessage: string) {
    super(publicMessage);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
    this.retryable = retryable;
    this.publicMessage = publicMessage;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}
