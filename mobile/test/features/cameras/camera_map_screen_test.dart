import 'package:flutter_starter/src/theme/theme.dart';
import 'dart:async';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_results.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_map_state.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/config/map_config.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_location_gateway.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/fixture_camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_map_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_view_config.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class Maps implements CameraMapRepository {
  int calls = 0;
  @override
  FutureEither<CameraMapResult> search(CameraMapQuery query,
      {CancelToken? cancelToken}) async {
    calls++;
    return const Right(
        CameraMapResult(items: [], hasMore: false, catalogVersion: 'v1'));
  }
}

class GPS implements CameraLocationGateway {
  int calls = 0;
  @override
  Future<CameraLocationResult> locate() async {
    calls++;
    return const CameraLocationResult(
        status: CameraLocationStatus.deniedForever);
  }

  @override
  Future<bool> checkPermission() async => false;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

class RejectedCatalog extends FixtureCameraRepository {
  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      const Left(ApiFailure('Expired', statusCode: 401));
}

class SlowCatalog extends FixtureCameraRepository {
  final pending = Completer<Either<Failure, List<DistrictOption>>>();
  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) =>
      pending.future;
}

class _MapLoader extends AssetLoader {
  const _MapLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
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
          'missing_key':
              'Chưa cấu hình khóa Vietmap. Bạn vẫn có thể xem danh mục Camera.',
          'demo_map': 'Bản đồ minh họa · dữ liệu demo',
          'invalid_viewport': 'Phóng to bản đồ để chọn vùng hợp lệ.',
          'update_required':
              'Mã truy cập camera đã hết hiệu lực. Vui lòng cập nhật cấu hình truy cập.',
          'load_failed': 'Không thể tải camera trong vùng này.',
          'retry': 'Thử lại',
          'stale_results': 'Kết quả cũ — chưa cập nhật cho tìm kiếm hiện tại.',
          'incomplete_catalog': 'Danh mục camera có thể chưa đầy đủ.',
          'viewport_limit': 'Phóng to để xem đủ camera',
          'nearby_limit':
              'Đang hiển thị các camera gần nhất, hãy giảm bán kính để xem đủ',
          'empty': 'Chưa tìm thấy camera trong vùng đã chọn.',
          'loading': 'Đang tải camera',
          'straight_distance': 'khoảng cách đường thẳng',
        },
        'camera': {
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
        'shared': {'retry': 'Thử lại', 'close': 'Đóng'},
      };
}

Widget _app(Widget home,
        {ThemeData? theme, Widget Function(BuildContext, Widget?)? builder}) =>
    EasyLocalization(
      supportedLocales: const [Locale('vi')],
      path: 'assets/translations',
      assetLoader: const _MapLoader(),
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'),
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: theme,
          builder: builder,
          home: home,
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'traffic loads before districts and refreshes shared edits on return',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'camera_traffic_layer_enabled': false});
    final catalog = SlowCatalog();
    CameraMapViewConfig? config;
    Widget screen(bool active) => _app(CameraMapScreen(
        repository: Maps(),
        locationGateway: GPS(),
        cameraRepository: catalog,
        onSelectCamera: (_) {},
        onOpenCameras: () {},
        active: active,
        connectionConfig: const MapConnectionConfig(apiKey: 'key'),
        mapBuilder: (context, value) {
          config = value;
          return const SizedBox();
        }));
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(config!.trafficEnabled, false);
    await tester.tap(find.text('Giao thông'));
    await tester.pumpAndSettle();
    expect(config!.trafficEnabled, true);
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('camera_traffic_layer_enabled', false);
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(config!.trafficEnabled, false);
    (tester.state(find.byType(CameraMapScreen)) as WidgetsBindingObserver)
        .didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    await prefs.setBool('camera_traffic_layer_enabled', true);
    (tester.state(find.byType(CameraMapScreen)) as WidgetsBindingObserver)
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(config!.trafficEnabled, true);
    catalog.pending.complete(const Right([]));
    await tester.pumpAndSettle();
  });
  testWidgets('background initialization does not mount canvas',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(() => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pumpWidget(_app(CameraMapScreen(
        repository: Maps(),
        locationGateway: GPS(),
        cameraRepository: FixtureCameraRepository(),
        onSelectCamera: (_) {},
        onOpenCameras: () {},
        mapBuilder: (context, config) =>
            const SizedBox(key: ValueKey('background-map')))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('background-map')), findsNothing);
  });
  testWidgets('stale limit explanation follows result query mode',
      (tester) async {
    await tester.pumpWidget(_app(Scaffold(
        body: CameraMapResults(
            state: const CameraMapState(
                mode: CameraMapMode.viewport,
                resultQuery: CameraMapQuery.nearby(lat: 10, lng: 106),
                result: CameraMapResult(
                    items: [], hasMore: true, catalogVersion: 'v1')),
            onSelectCamera: (_) {},
            onRetry: () {}))));
    await tester.pumpAndSettle();
    expect(find.textContaining('hãy giảm bán kính'), findsOneWidget);
    expect(find.textContaining('Phóng to để xem đủ'), findsNothing);
  });
  testWidgets(
      'results show stale coverage distance limits and route selected camera',
      (tester) async {
    const camera = Camera(
        id: 'c', name: 'Camera C', provinceId: 'tp_hcm', playbackEndpoint: '');
    Camera? selected;
    const result = CameraMapResult(
        items: [CameraMapItem(camera: camera, distanceMeters: 1450)],
        hasMore: true,
        catalogVersion: 'v1',
        isStale: true,
        coverage: 'partial');
    Future<void> render(CameraMapMode mode) async {
      await tester.pumpWidget(_app(Scaffold(
          body: CameraMapResults(
              state: CameraMapState(mode: mode, result: result),
              onSelectCamera: (camera) => selected = camera,
              onRetry: () {}))));
      await tester.pumpAndSettle();
    }
    await render(CameraMapMode.viewport);
    expect(find.textContaining('Kết quả cũ'), findsOneWidget);
    expect(find.textContaining('chưa đầy đủ'), findsOneWidget);
    expect(find.textContaining('Phóng to để xem đủ'), findsOneWidget);
    expect(find.textContaining('1.4 km'), findsOneWidget);
    await tester.tap(find.text('Camera C'));
    expect(selected, camera);
    await render(CameraMapMode.nearby);
    expect(find.textContaining('hãy giảm bán kính'), findsOneWidget);
  });
  testWidgets('district unauthorized reports update required without a map key',
      (tester) async {
    await tester.pumpWidget(_app(CameraMapScreen(
        repository: Maps(),
        locationGateway: GPS(),
        cameraRepository: RejectedCatalog(),
        onSelectCamera: (_) {},
        onOpenCameras: () {},
        connectionConfig: const MapConnectionConfig())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mã truy cập camera đã hết hiệu lực'),
        findsOneWidget);
  });
  testWidgets('320dp and large text keep controls and fallback usable',
      (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(
        CameraMapScreen(
            repository: Maps(),
            locationGateway: GPS(),
            cameraRepository: FixtureCameraRepository(),
            onSelectCamera: (_) {},
            onOpenCameras: () {},
            connectionConfig: const MapConnectionConfig()),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'initial viewport does not ask for GPS and inactive removes canvas',
      (tester) async {
    final gps = GPS(), maps = Maps();
    CameraMapViewConfig? config;
    Widget screen(bool active) => _app(CameraMapScreen(
        repository: maps,
        locationGateway: gps,
        cameraRepository: FixtureCameraRepository(),
        onSelectCamera: (_) {},
        onOpenCameras: () {},
        active: active,
        connectionConfig: const MapConnectionConfig(apiKey: 'test'),
        mapBuilder: (context, value) {
          config = value;
          return const SizedBox(key: ValueKey('fake-map'));
        }));
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(config!.center.latitude, 10.7769);
    expect(config!.zoom, 13);
    expect(gps.calls, 0);
    config!.onIdle!(const MapBounds(106, 10, 107, 11), 13,
        const MapCoordinate(10.7769, 106.7009));
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();
    expect(maps.calls, 1);
    await tester.pumpWidget(screen(false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fake-map')), findsNothing);
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    (tester.state(find.byType(CameraMapScreen)) as WidgetsBindingObserver)
        .didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byKey(const ValueKey('fake-map')), findsNothing);
    (tester.state(find.byType(CameraMapScreen)) as WidgetsBindingObserver)
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
    expect(gps.calls, 0);
  });
  testWidgets('missing key explains fallback and nearby denial offers settings',
      (tester) async {
    final gps = GPS();
    await tester.pumpWidget(_app(CameraMapScreen(
        repository: Maps(),
        locationGateway: gps,
        cameraRepository: FixtureCameraRepository(),
        onSelectCamera: (_) {},
        onOpenCameras: () {},
        connectionConfig: const MapConnectionConfig())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa cấu hình khóa Vietmap'), findsOneWidget);
    await tester.tap(find.text('Gần tôi'));
    await tester.pumpAndSettle();
    expect(gps.calls, 1);
    expect(find.text('1 km'), findsOneWidget);
    expect(find.text('2 km'), findsOneWidget);
    expect(find.text('5 km'), findsOneWidget);
    expect(find.text('Mở cài đặt ứng dụng'), findsOneWidget);
  });
  testWidgets(
      'verified backend coverage does not show an incomplete catalog warning',
      (tester) async {
    await tester.pumpWidget(_app(Scaffold(
        body: CameraMapResults(
            state: const CameraMapState(
                result: CameraMapResult(
                    items: [],
                    hasMore: false,
                    catalogVersion: 'v1',
                    coverage: 'verified',
                    syncState: 'synced')),
            onSelectCamera: (_) {},
            onRetry: () {}))));
    expect(find.text('Danh mục camera có thể chưa đầy đủ.'), findsNothing);
  });
  testWidgets(
      'map controls retain readable contrast in the product light theme',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(
          CameraMapScreen(
              repository: Maps(),
              locationGateway: GPS(),
              cameraRepository: SlowCatalog(),
              onSelectCamera: (_) {},
              onOpenCameras: () {},
              mapBuilder: (context, config) => const SizedBox()),
          theme: buildLightTheme(primaryColorHex: '#00796B')));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
