import 'reflect-metadata';
import dotenv from 'dotenv';
import { createApp } from './create-app.js';
import { loadConfig } from './config/config.js';
import { SafeLogger } from './http/safe-logger.js';

dotenv.config();

async function bootstrap() {
  const config = loadConfig(process.env);
  const logger = new SafeLogger();
  const app = await createApp({ config, logger });

  await app.listen(config.port, config.host);
  logger.log(`Camera backend listening on http://${config.host}:${config.port}`);
}

bootstrap().catch((err) => {
  console.error('Fatal startup error:', err);
  process.exit(1);
});
