import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../middleware/dio_logging_interceptor.dart';

/// Connection settings for Camera A1 service.
/// Build settings (--dart-define) override values loaded from .env.
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
    final env = dotenv.isInitialized ? dotenv.env : const <String, String>{};

    return CameraConnectionConfig(
      baseUrl: const bool.hasEnvironment('CAMERA_API_BASE_URL')
          ? const String.fromEnvironment('CAMERA_API_BASE_URL')
          : env['CAMERA_API_BASE_URL'] ?? '',
      readerKey: const bool.hasEnvironment('CAMERA_READER_KEY')
          ? const String.fromEnvironment('CAMERA_READER_KEY')
          : env['CAMERA_READER_KEY'] ?? '',
      demoMode: const bool.hasEnvironment('CAMERA_DEMO_MODE')
          ? const bool.fromEnvironment('CAMERA_DEMO_MODE')
          : bool.tryParse(env['CAMERA_DEMO_MODE'] ?? '') ?? false,
    );
  }

  bool get isValid =>
      demoMode || (baseUrl.trim().isNotEmpty && readerKey.trim().isNotEmpty);
}

class AppConfig {
  AppConfig._();
  static late final Dio dio;
  static CameraConnectionConfig cameraConfig =
      CameraConnectionConfig.fromEnvironment();

  static String get baseUrl => cameraConfig.baseUrl;
  static bool get isConfigured => cameraConfig.isValid;

  static Future<void> init({CameraConnectionConfig? config}) async {
    cameraConfig = config ?? CameraConnectionConfig.fromEnvironment();

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
