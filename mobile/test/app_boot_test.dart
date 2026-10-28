import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/app.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/routing/app_router.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_navigation_shell.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAssetLoader extends AssetLoader {
  const TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'navigation': {'map': 'Bản đồ', 'cameras': 'Camera'},
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
        'reset_failed': 'Không thể đặt lại: {}',
        'favorites_update_failed': 'Lỗi cập nhật Quan tâm: {}',
        'reset': 'Đặt lại',
        'load_failed': 'Không thể tải danh sách camera',
        'live': 'Trực tiếp',
        'snapshot': 'Ảnh',
        'snapshot_static': 'Ảnh tĩnh',
        'snapshot_load_failed': 'Không thể tải hình ảnh camera',
        'directions': 'Chỉ đường',
        'grid_title': 'Lưới camera',
        'multi_empty': 'Chưa có camera Quan tâm khả dụng',
        'back': 'Quay lại',
        'fullscreen': 'Toàn màn hình',
        'favorite': 'Quan tâm',
        'unfavorite': 'Bỏ quan tâm',
        'view_grid_tooltip': 'Xem lưới',
        'close': 'Đóng',
        'clear_search': 'Xóa tìm kiếm',
      },
      'map_discovery': {
        'title': 'Bản đồ',
        'viewport': 'Vùng đang xem',
        'nearby': 'Gần tôi',
        'refresh_location': 'Cập nhật vị trí',
        'district': 'Quận / huyện',
        'all_districts': 'Tất cả quận / huyện',
        'traffic': 'Giao thông',
        'street': 'Đường phố',
        'hybrid': 'Vệ tinh',
        'open_cameras': 'Mở Camera',
        'locating': 'Đang lấy vị trí…',
        'location_denied': 'Quyền vị trí bị từ chối. Thử lại',
        'app_settings': 'Mở cài đặt ứng dụng',
        'location_settings': 'Bật dịch vụ vị trí',
        'location_timeout': 'Hết thời gian lấy vị trí. Thử lại',
        'location_failed': 'Không lấy được vị trí. Thử lại',
        'missing_key': 'Chưa cấu hình khóa Vietmap. Bạn vẫn có thể xem danh mục Camera.',
        'demo_map': 'Bản đồ minh họa · dữ liệu demo',
        'invalid_viewport': 'Phóng to bản đồ để chọn vùng hợp lệ.',
        'update_required': 'Mã truy cập camera đã hết hiệu lực. Vui lòng cập nhật cấu hình truy cập.',
        'load_failed': 'Không thể tải camera trong vùng này.',
        'retry': 'Thử lại',
        'stale_results': 'Kết quả cũ — chưa cập nhật cho tìm kiếm hiện tại.',
        'incomplete_catalog': 'Danh mục camera có thể chưa đầy đủ.',
        'viewport_limit': 'Phóng to để xem đủ camera',
        'nearby_limit': 'Đang hiển thị các camera gần nhất, hãy giảm bán kính để xem đủ',
        'empty': 'Chưa tìm thấy camera trong vùng đã chọn.',
        'loading': 'Đang tải camera',
        'straight_distance': 'khoảng cách đường thẳng',
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

  testWidgets('boots_map_without_session_redirect',
      (WidgetTester tester) async {
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
          routerConfig:
              createAppRouter(navigatorKey: GlobalKey<NavigatorState>()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CameraMapFeature), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    expect(find.text('Login'), findsNothing);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('missing_config_shows_connection_state',
      (WidgetTester tester) async {
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
          routerConfig:
              createAppRouter(navigatorKey: GlobalKey<NavigatorState>()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Không thể kết nối máy chủ'), findsOneWidget);
  });
}
