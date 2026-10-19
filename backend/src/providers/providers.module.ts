import { Module, Global } from '@nestjs/common';
import { CAMERA_PROVIDER, CameraProvider } from './camera-provider.js';
import { FixtureProvider } from './fixture.provider.js';
import { NotisProvider } from './notis.provider.js';
import { APP_CONFIG } from '../config/config.module.js';
import { AppConfig } from '../config/config.js';

@Global()
@Module({
  providers: [
    {
      provide: CAMERA_PROVIDER,
      useFactory: (config: AppConfig): CameraProvider => {
        if (config.cameraProviderMode === 'fixture') {
          return new FixtureProvider();
        }
        return new NotisProvider({
          authToken: config.notisAuthToken,
          timeoutMs: config.upstreamTimeoutMs,
        });
      },
      inject: [APP_CONFIG],
    },
  ],
  exports: [CAMERA_PROVIDER],
})
export class ProvidersModule {}
