import { NestFactory, Reflector } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { LoggerService } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';
import { loadConfig, AppConfig } from './config/config.js';
import { ApiErrorFilter } from './http/api-error.filter.js';
import { ApiKeyGuard } from './http/api-key.guard.js';
import { RateLimitInterceptor } from './http/rate-limit.js';
import { sanitizeOrGenerateRequestId } from './http/request-context.js';
import { SafeLogger } from './http/safe-logger.js';

export interface CreateAppOptions {
  config?: AppConfig;
  logger?: LoggerService;
  testingControllers?: any[];
}

export async function createApp(options?: CreateAppOptions): Promise<NestFastifyApplication> {
  const config = options?.config || loadConfig();
  const logger = options?.logger || new SafeLogger();

  const fastifyAdapter = new FastifyAdapter({
    bodyLimit: config.bodyLimitBytes,
    trustProxy: false,
    logger: false,
  });

  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule.forRoot({
      config,
      testingControllers: options?.testingControllers,
    }),
    fastifyAdapter,
    { logger, abortOnError: false },
  );

  const fastifyInstance = app.getHttpAdapter().getInstance();

  fastifyInstance.addHook('onRequest', (request: any, reply: any, done: () => void) => {
    const rawId = request.headers['x-request-id'];
    const requestId = sanitizeOrGenerateRequestId(rawId);
    request.requestId = requestId;
    request.startTime = Date.now();
    reply.header('x-request-id', requestId);
    done();
  });

  fastifyInstance.addHook('onResponse', (request: any, reply: any, done: () => void) => {
    const durationMs = request.startTime ? Date.now() - request.startTime : 0;
    const route = request.routeOptions?.url || request.raw?.url?.split('?')[0] || request.url;
    logger.log({
      method: request.method,
      route,
      status: reply.statusCode,
      durationMs,
      requestId: request.requestId,
    });
    done();
  });

  const reflector = app.get(Reflector);
  app.useGlobalGuards(new ApiKeyGuard(reflector, config));
  app.useGlobalInterceptors(new RateLimitInterceptor(config));
  app.useGlobalFilters(new ApiErrorFilter());

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Camera Backend API')
    .setDescription('Traffic camera catalog and snapshot service for TP.HCM')
    .setVersion('1.0.0')
    .addApiKey({ type: 'apiKey', name: 'x-api-key', in: 'header' }, 'ApiKeyAuth')
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('docs', app, document);

  await app.init();

  await fastifyInstance.ready();


  return app;
}
