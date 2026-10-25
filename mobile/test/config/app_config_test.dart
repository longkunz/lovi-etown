import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

const hasBuildOverrides = bool.hasEnvironment('CAMERA_API_BASE_URL') ||
    bool.hasEnvironment('CAMERA_READER_KEY') ||
    bool.hasEnvironment('CAMERA_DEMO_MODE');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(dotenv.clean);

  group('runtime camera configuration', () {
    test('missing .env leaves the connection unconfigured', () {
      dotenv.clean();
      final config = CameraConnectionConfig.fromEnvironment();

      expect(config.baseUrl, isEmpty);
      expect(config.readerKey, isEmpty);
      expect(config.demoMode, isFalse);
      expect(config.isValid, isFalse);
    });

    test('reads connection settings from loaded .env', () {
      dotenv.loadFromString(envString: '''
CAMERA_API_BASE_URL=https://runtime.example
CAMERA_READER_KEY=runtime-reader-key
CAMERA_DEMO_MODE=false
''');
      final config = CameraConnectionConfig.fromEnvironment();

      expect(config.baseUrl, 'https://runtime.example');
      expect(config.readerKey, 'runtime-reader-key');
      expect(config.demoMode, isFalse);
      expect(config.isValid, isTrue);
    });

    test('enables demo mode from .env without connection credentials', () {
      dotenv.loadFromString(envString: 'CAMERA_DEMO_MODE=true');
      final config = CameraConnectionConfig.fromEnvironment();

      expect(config.demoMode, isTrue);
      expect(config.isValid, isTrue);
    });

    test('missing or invalid demo values default to false', () {
      for (final value in ['', 'not-a-bool']) {
        dotenv.loadFromString(envString: 'CAMERA_DEMO_MODE=$value');
        expect(CameraConnectionConfig.fromEnvironment().demoMode, isFalse);
      }
    });

    test('initialization rereads settings after .env loads', () async {
      dotenv.clean();
      // Simulate configuration being accessed before bootstrap loads .env.
      AppConfig.cameraConfig = CameraConnectionConfig.fromEnvironment();
      dotenv.loadFromString(envString: '''
CAMERA_API_BASE_URL=https://runtime.example
CAMERA_READER_KEY=runtime-reader-key
''');

      await AppConfig.init();

      expect(AppConfig.isConfigured, isTrue);
      expect(AppConfig.dio.options.baseUrl, 'https://runtime.example');
      expect(AppConfig.dio.options.headers['x-api-key'], 'runtime-reader-key');
      AppConfig.dio.close();
    });
  }, skip: hasBuildOverrides);

  test('build settings override .env including explicit demo false', () {
    dotenv.loadFromString(envString: '''
CAMERA_API_BASE_URL=https://runtime.example
CAMERA_READER_KEY=runtime-reader-key
CAMERA_DEMO_MODE=true
''');
    final config = CameraConnectionConfig.fromEnvironment();

    expect(config.baseUrl, 'https://override.example');
    expect(config.readerKey, 'override-reader-key');
    expect(config.demoMode, isFalse);
  }, skip: !hasBuildOverrides);

  test('runtime .env is bundled for application bootstrap', () async {
    final content = await rootBundle.loadString('.env');
    expect(content.isNotEmpty, isTrue);
  });
}
