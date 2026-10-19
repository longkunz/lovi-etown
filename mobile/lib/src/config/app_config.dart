import 'package:dio/dio.dart';
import '../middleware/dio_logging_interceptor.dart';

/// Connection settings for Camera A1 service.
/// Read from build environment (--dart-define) or injected in tests.
class CameraConnectionConfig {
  final String baseUrl;
  final String readerKey;
  final bool demoMode;

  const CameraConnectionConfig({
    required this.baseUrl,
    required this.readerKey,
    this.demoMode = false,
  });

  factory CameraConnectionConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment('CAMERA_API_BASE_URL', defaultValue: '');
    const readerKey = String.fromEnvironment('CAMERA_READER_KEY', defaultValue: '');
    const demoMode = bool.fromEnvironment('CAMERA_DEMO_MODE', defaultValue: false);

    return const CameraConnectionConfig(
      baseUrl: baseUrl,
      readerKey: readerKey,
      demoMode: demoMode,
    );
  }

  bool get isValid => demoMode || (baseUrl.trim().isNotEmpty && readerKey.trim().isNotEmpty);
}

class AppConfig {
  AppConfig._();
  static late final Dio dio;
  static CameraConnectionConfig cameraConfig = CameraConnectionConfig.fromEnvironment();

  static String get baseUrl => cameraConfig.baseUrl;
  static bool get isConfigured => cameraConfig.isValid;

  static Future<void> init({CameraConnectionConfig? config}) async {
    if (config != null) {
      cameraConfig = config;
    }

    dio = Dio(
      BaseOptions(
        baseUrl: cameraConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (cameraConfig.readerKey.isNotEmpty)
            'x-api-key': cameraConfig.readerKey,
        },
      ),
    );

    dio.interceptors.add(DioLoggingInterceptor());
  }
}
