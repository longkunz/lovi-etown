import { Module, Global, DynamicModule } from '@nestjs/common';
import { loadConfig, AppConfig } from './config.js';

export const APP_CONFIG = 'APP_CONFIG';

@Global()
@Module({})
export class ConfigModule {
  static forRoot(customConfig?: AppConfig): DynamicModule {
    return {
      module: ConfigModule,
      providers: [
        {
          provide: APP_CONFIG,
          useFactory: (): AppConfig => customConfig || loadConfig(),
        },
      ],
      exports: [APP_CONFIG],
    };
  }
}
