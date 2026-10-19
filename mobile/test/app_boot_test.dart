import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/app.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/routing/app_router.dart';
import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAssetLoader extends AssetLoader {
  const TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'shared': {
        'get_started': 'Bắt đầu',
        'retry': 'Thử lại',
        'close': 'Đóng',
        'error': 'Đã có lỗi xảy ra',
        'connection_error': 'Không thể kết nối máy chủ',
        'demo_mode_badge': 'Dữ liệu mẫu',
      },
      'camera': {
        'title': 'Camera giao thông',
        'search_hint': 'Tìm tên đường, giao lộ...',
        'all_districts': 'Tất cả quận/huyện',
        'favorites_title': 'Quan tâm',
        'empty_favorites': 'Chưa có camera quan tâm',
        'view_card': 'Thẻ',
        'view_grid': 'Lưới',
        'view_list': 'Danh sách',
      },
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('demo_requires_explicit_flag', () {
    const defaultConfig = CameraConnectionConfig(
      baseUrl: 'http://localhost:3000',
      readerKey: 'test_key',
    );
    expect(defaultConfig.demoMode, isFalse);

    const explicitDemo = CameraConnectionConfig(
      baseUrl: '',
      readerKey: '',
      demoMode: true,
    );
    expect(explicitDemo.demoMode, isTrue);
  });

  testWidgets('boots_camera_without_session_redirect', (WidgetTester tester) async {
    AppConfig.cameraConfig = const CameraConnectionConfig(
      baseUrl: 'http://10.0.2.2:3000',
      readerKey: 'test_reader_key',
      demoMode: true,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'assets/translations',
        assetLoader: const TestAssetLoader(),
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: App(
          routerConfig: createAppRouter(navigatorKey: GlobalKey<NavigatorState>()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CameraFeature), findsOneWidget);
    expect(find.text('Login'), findsNothing);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('missing_config_shows_connection_state', (WidgetTester tester) async {
    AppConfig.cameraConfig = const CameraConnectionConfig(
      baseUrl: '',
      readerKey: '',
      demoMode: false,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'assets/translations',
        assetLoader: const TestAssetLoader(),
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: App(
          routerConfig: createAppRouter(navigatorKey: GlobalKey<NavigatorState>()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Không thể kết nối máy chủ'), findsOneWidget);
  });
}
