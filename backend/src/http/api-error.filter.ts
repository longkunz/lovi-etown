import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { FastifyReply, FastifyRequest } from 'fastify';
import { ApiError } from './api-error.js';
import { sanitizeOrGenerateRequestId } from './request-context.js';

@Catch()
export class ApiErrorFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<FastifyReply>();
    const request = ctx.getRequest<FastifyRequest>();

    const requestId =
      (request as any).requestId ||
      sanitizeOrGenerateRequestId(request.headers['x-request-id']);

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'INTERNAL_ERROR';
    let message = 'An unexpected error occurred';
    let retryable = false;

    if (exception instanceof ApiError) {
      status = exception.status;
      code = exception.code;
      message = exception.publicMessage;
      retryable = exception.retryable;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      const rawMessage = exception.message || '';
      const isJsonError = /JSON|Unexpected token|Unexpected end|parsing/i.test(rawMessage);

      if (typeof res === 'object' && res !== null) {
        const bodyObj = res as Record<string, any>;
        const bodyMsg = Array.isArray(bodyObj.message) ? bodyObj.message.join(', ') : bodyObj.message || '';
        const isBodyJsonError = /JSON|Unexpected token|Unexpected end|parsing/i.test(bodyMsg);

        if (status === 400 && (isJsonError || isBodyJsonError)) {
          code = 'INVALID_JSON';
          message = 'Malformed JSON body or invalid syntax';
        } else if (status === 413) {
          code = 'PAYLOAD_TOO_LARGE';
          message = 'Payload too large, maximum size is 64 KiB';
        } else {
          code = bodyObj.code || (status === 404 ? 'NOT_FOUND' : status === 400 ? 'VALIDATION_ERROR' : 'HTTP_ERROR');
          message = bodyMsg || exception.message;
        }
      } else {
        if (status === 400 && isJsonError) {
          code = 'INVALID_JSON';
          message = 'Malformed JSON body or invalid syntax';
        } else if (status === 413) {
          code = 'PAYLOAD_TOO_LARGE';
          message = 'Payload too large, maximum size is 64 KiB';
        } else {
          message = String(res);
        }
      }
      retryable = status >= 500 && status !== 501;
    } else if (typeof exception === 'object' && exception !== null) {
      const err = exception as any;
      const isSyntaxError = exception instanceof SyntaxError || err.name === 'SyntaxError';
      const isJsonError = (err.message && /JSON|Unexpected token|Unexpected end/i.test(err.message));

      if (err.statusCode === 413 || err.code === 'FST_ERR_CTP_BODY_TOO_LARGE') {
        status = 413;
        code = 'PAYLOAD_TOO_LARGE';
        message = 'Payload too large, maximum size is 64 KiB';
        retryable = false;
      } else if (isSyntaxError || isJsonError || err.statusCode === 400 || err.code === 'FST_ERR_CTP_INVALID_CONTENT_LENGTH') {
        status = 400;
        code = err.code === 'VALIDATION_ERROR' ? 'VALIDATION_ERROR' : 'INVALID_JSON';
        message = 'Malformed JSON body or invalid syntax';
        retryable = false;
      } else if (err.status || err.statusCode) {
        status = err.status || err.statusCode;
        code = err.code || 'BAD_REQUEST';
        message = err.message || 'Request failed';
        retryable = status >= 500;
      }
    }

    response.header('x-request-id', requestId);
    response.status(status).send({
      error: {
        code,
        message,
        requestId,
        retryable,
      },
    });
  }
}
