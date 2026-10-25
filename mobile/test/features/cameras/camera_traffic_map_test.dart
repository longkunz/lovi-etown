import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_traffic_map_viewer_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_traffic_map_card.dart';

class TrafficMapTestAssetLoader extends AssetLoader {
  const TrafficMapTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'shared': {
        'retry': 'Thử lại',
        'close': 'Đóng',
      },
      'camera': {
        'traffic_map_title': 'Bản đồ lưu lượng',
        'traffic_map_toggle': 'Bật/tắt lưu lượng giao thông',
        'traffic_map_fullscreen': 'Xem bản đồ toàn màn hình',
        'traffic_map_recenter': 'Về vị trí camera',
        'traffic_map_no_location': 'Chưa có dữ liệu vị trí cho camera này',
      },
    };
  }
}

Widget buildTestApp({required Widget child}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
    path: 'assets/translations',
    assetLoader: const TrafficMapTestAssetLoader(),
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    saveLocale: false,
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  const testCameraWithLocation = Camera(
    id: 'cam_hang_xanh',
    name: 'Ngã tư Hàng Xanh',
    provinceId: 'tp_hcm',
    district: 'Bình Thạnh',
    address: 'Điện Biên Phủ - Xô Viết Nghệ Tĩnh',
    playbackEndpoint: '/v1/cameras/cam_hang_xanh/playback',
    latitude: 10.8018,
    longitude: 106.7114,
  );

  const testCameraNoLocation = Camera(
    id: 'cam_no_loc',
    name: 'Camera Không Tọa Độ',
    provinceId: 'tp_hcm',
    playbackEndpoint: '/v1/cameras/cam_no_loc/playback',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CameraTrafficMapCard', () {
    testWidgets('renders nothing when camera has no location', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const Scaffold(
            body: SingleChildScrollView(
              child: CameraTrafficMapCard(camera: testCameraNoLocation),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CameraTrafficMapCard), findsOneWidget);
      expect(find.byType(CameraMapCanvas), findsNothing);
      expect(find.text('Bản đồ lưu lượng'), findsNothing);
    });

    testWidgets('renders map card and controls when camera has location',
        (tester) async {
      CameraTrafficMapConfig? capturedConfig;

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: SingleChildScrollView(
              child: CameraTrafficMapCard(
                camera: testCameraWithLocation,
                mapBuilder: (context, config) {
                  capturedConfig = config;
                  return Container(
                    key: const ValueKey('mock_google_map'),
                    color: Colors.blueGrey,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card title and mock map rendered
      expect(find.text('Bản đồ lưu lượng'), findsOneWidget);
      expect(find.byKey(const ValueKey('mock_google_map')), findsOneWidget);

      // Verify config values
      expect(capturedConfig, isNotNull);
      expect(capturedConfig!.center.latitude, 10.8018);
      expect(capturedConfig!.center.longitude, 106.7114);
      expect(capturedConfig!.trafficEnabled, isTrue);
      expect(capturedConfig!.markers.length, 1);
      expect(capturedConfig!.markers.first.id, 'cam_hang_xanh');

      // Verify action buttons exist by key
      expect(find.byKey(const ValueKey('traffic_map_recenter_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('traffic_layer_toggle_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('traffic_map_fullscreen_button')),
          findsOneWidget);
    });

    testWidgets('traffic toggle flips state and updates SharedPreferences',
        (tester) async {
      CameraTrafficMapConfig? capturedConfig;

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: SingleChildScrollView(
              child: CameraTrafficMapCard(
                camera: testCameraWithLocation,
                mapBuilder: (context, config) {
                  capturedConfig = config;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedConfig!.trafficEnabled, isTrue);

      // Tap traffic toggle button
      await tester
          .tap(find.byKey(const ValueKey('traffic_layer_toggle_button')));
      await tester.pumpAndSettle();

      expect(capturedConfig!.trafficEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getBool(CameraTrafficMapCard.prefTrafficEnabledKey), isFalse);
    });

    testWidgets('fullscreen button triggers onOpenFullscreen callback',
        (tester) async {
      var fullscreenTapped = false;

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: SingleChildScrollView(
              child: CameraTrafficMapCard(
                camera: testCameraWithLocation,
                onOpenFullscreen: () => fullscreenTapped = true,
                mapBuilder: (context, config) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('traffic_map_fullscreen_button')));
      await tester.pumpAndSettle();

      expect(fullscreenTapped, isTrue);
    });

    testWidgets('all map card action buttons have tap target size >= 48x48',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: SingleChildScrollView(
              child: CameraTrafficMapCard(
                camera: testCameraWithLocation,
                mapBuilder: (context, config) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final recenterFinder =
          find.byKey(const ValueKey('traffic_map_recenter_button'));
      final toggleFinder =
          find.byKey(const ValueKey('traffic_layer_toggle_button'));
      final fullscreenFinder =
          find.byKey(const ValueKey('traffic_map_fullscreen_button'));

      expect(recenterFinder, findsOneWidget);
      expect(toggleFinder, findsOneWidget);
      expect(fullscreenFinder, findsOneWidget);

      final recenterSize = tester.getSize(recenterFinder);
      final toggleSize = tester.getSize(toggleFinder);
      final fullscreenSize = tester.getSize(fullscreenFinder);

      expect(recenterSize.width, greaterThanOrEqualTo(48.0));
      expect(recenterSize.height, greaterThanOrEqualTo(48.0));
      expect(toggleSize.width, greaterThanOrEqualTo(48.0));
      expect(toggleSize.height, greaterThanOrEqualTo(48.0));
      expect(fullscreenSize.width, greaterThanOrEqualTo(48.0));
      expect(fullscreenSize.height, greaterThanOrEqualTo(48.0));

      // Verify semantics
      expect(find.bySemanticsLabel('Về vị trí camera'), findsOneWidget);
      expect(find.bySemanticsLabel('Bật/tắt lưu lượng giao thông'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Xem bản đồ toàn màn hình'), findsOneWidget);
    });

    testWidgets(
        'map card adapts cleanly under high contrast and large text scale 2.0',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildTestApp(
          child: MediaQuery(
            data: const MediaQueryData(
              highContrast: true,
              textScaler: TextScaler.linear(2),
              size: Size(320, 640),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: CameraTrafficMapCard(
                  camera: testCameraWithLocation,
                  mapBuilder: (context, config) => const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('traffic_map_recenter_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('traffic_layer_toggle_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('traffic_map_fullscreen_button')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CameraTrafficMapViewerScreen', () {
    testWidgets('renders fullscreen map and app bar with camera info',
        (tester) async {
      CameraTrafficMapConfig? capturedConfig;

      await tester.pumpWidget(
        buildTestApp(
          child: CameraTrafficMapViewerScreen(
            camera: testCameraWithLocation,
            mapBuilder: (context, config) {
              capturedConfig = config;
              return Container(key: const ValueKey('mock_fullscreen_map'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ngã tư Hàng Xanh'), findsOneWidget);
      expect(find.text('Điện Biên Phủ - Xô Viết Nghệ Tĩnh'), findsOneWidget);
      expect(find.byKey(const ValueKey('mock_fullscreen_map')), findsOneWidget);
      expect(capturedConfig?.trafficEnabled, isTrue);
      expect(find.byKey(const ValueKey('fullscreen_directions_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('fullscreen_traffic_recenter_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('fullscreen_traffic_toggle_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('fullscreen_map_type_button')),
          findsOneWidget);

      // Verify all floating action buttons have min touch target >= 48x48
      final recenterSize = tester.getSize(
          find.byKey(const ValueKey('fullscreen_traffic_recenter_button')));
      final toggleSize = tester.getSize(
          find.byKey(const ValueKey('fullscreen_traffic_toggle_button')));
      final mapTypeSize = tester
          .getSize(find.byKey(const ValueKey('fullscreen_map_type_button')));
      final directionsSize = tester
          .getSize(find.byKey(const ValueKey('fullscreen_directions_button')));

      expect(recenterSize.width, greaterThanOrEqualTo(48.0));
      expect(recenterSize.height, greaterThanOrEqualTo(48.0));
      expect(toggleSize.width, greaterThanOrEqualTo(48.0));
      expect(toggleSize.height, greaterThanOrEqualTo(48.0));
      expect(mapTypeSize.width, greaterThanOrEqualTo(48.0));
      expect(mapTypeSize.height, greaterThanOrEqualTo(48.0));
      expect(directionsSize.width, greaterThanOrEqualTo(48.0));
      expect(directionsSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('viewer toggles map type', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: CameraTrafficMapViewerScreen(
            camera: testCameraWithLocation,
            mapBuilder: (context, config) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapTypeButton =
          find.byKey(const ValueKey('fullscreen_map_type_button'));
      expect(mapTypeButton, findsOneWidget);

      await tester.tap(mapTypeButton);
      await tester.pumpAndSettle();

      // Tooltip should have updated to 'Bản đồ chuẩn'
      expect(find.byTooltip('Bản đồ chuẩn'), findsOneWidget);
    });

    testWidgets('viewer displays fallback message if camera has no location',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child:
              const CameraTrafficMapViewerScreen(camera: testCameraNoLocation),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text('Chưa có dữ liệu vị trí cho camera này'), findsOneWidget);
    });
  });
}
