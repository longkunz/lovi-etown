import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/config/map_config.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_canvas.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/vietmap_style_loader.dart';

class FakeLoader extends VietmapStyleLoader {
  bool failAux = false;
  final loaded = <String>[];
  @override
  Future<Map<String, dynamic>> load(String style, String key) async {
    loaded.add(style);
    if (failAux && style != 'tm') {
      throw const VietmapStyleFailure(VietmapStyleFailureKind.unauthorized);
    }
    return {
      'version': 8,
      'sources': {style: <String, dynamic>{}},
      'layers': [
        {'id': style}
      ]
    };
  }
}

class DelayedLoader extends FakeLoader {
  final first = Completer<Map<String, dynamic>>();
  bool initial = true;
  @override
  Future<Map<String, dynamic>> load(String style, String key) {
    if (initial) {
      initial = false;
      return first.future;
    }
    return super.load(style, key);
  }
}

class FakeController implements CameraMapCanvasController {
  int markers = 0;
  int clears = 0;
  int moves = 0;
  int viewportQueries = 0;
  MapCoordinate? radiusCenter;
  double? radius;
  @override
  Future<void> addMarker(CameraMapMarker marker) async {
    markers++;
  }

  @override
  Future<void> clearMarkers() async {
    clears++;
    markers = 0;
  }

  @override
  Future<void> moveTo(double latitude, double longitude, {double? zoom}) async {
    moves++;
  }

  @override
  Future<void> setRadius(MapCoordinate? center, double? meters) async {
    radiusCenter = center;
    radius = meters;
  }

  @override
  Future<CameraMapViewport> getViewport() async {
    viewportQueries++;
    return const CameraMapViewport(
        MapBounds(106, 10, 107, 11), 16, MapCoordinate(10.8, 106.7));
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Widget localized(Widget child) => EasyLocalization(
        supportedLocales: const [Locale('vi')],
        startLocale: const Locale('vi'),
        fallbackLocale: const Locale('vi'),
        saveLocale: false,
        path: 'assets/translations',
        child: Builder(
            builder: (context) => MaterialApp(
                  locale: context.locale,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  home: child,
                )),
      );
  testWidgets(
      'markers wait for style; repeated ready is idempotent; idle queries visible region',
      (tester) async {
    final loader = FakeLoader();
    final controller = FakeController();
    late VoidCallback ready;
    late VoidCallback idle;
    late void Function(CameraMapCanvasController) created;
    var idleCount = 0;
    await tester.pumpWidget(MaterialApp(
        home: CameraMapCanvas(
            connectionConfig: const MapConnectionConfig(apiKey: 'test'),
            styleLoader: loader,
            config: CameraMapViewConfig(
                center: const MapCoordinate(10, 106),
                zoom: 12,
                trafficEnabled: true,
                markers: const [
                  CameraMapMarker(
                      id: 'one',
                      position: MapCoordinate(10, 106),
                      title: 'Camera')
                ],
                radiusCenter: const MapCoordinate(10, 106),
                radiusMeters: 1000,
                onIdle: (_, __, ___) => idleCount++),
            nativeBuilder:
                (context, style, config, onCreated, onReady, onIdle) {
              created = onCreated;
              ready = onReady;
              idle = onIdle;
              expect((jsonDecode(style)['sources'] as Map).keys,
                  containsAll(['tm', 'tf']));
              return const SizedBox();
            })));
    await tester.pumpAndSettle();
    created(controller);
    expect(controller.markers, 0);
    ready();
    await tester.pumpAndSettle();
    expect(controller.markers, 1);
    expect(controller.radius, 1000);
    expect(idleCount, 1);
    ready();
    await tester.pumpAndSettle();
    expect(controller.clears, 1);
    idle();
    await tester.pumpAndSettle();
    expect(controller.viewportQueries, 2);
  });
  testWidgets(
      'style switch preserves viewport and ignores previous callbacks and handles',
      (tester) async {
    final loader = FakeLoader();
    final first = FakeController();
    final second = FakeController();
    late VoidCallback ready;
    late void Function(CameraMapCanvasController) created;
    late CameraMapViewConfig nativeConfig;
    CameraMapHandle? handle;
    Widget app(CameraMapType type, {bool active = true}) => MaterialApp(
        home: CameraMapCanvas(
            active: active,
            connectionConfig: const MapConnectionConfig(apiKey: 'test'),
            styleLoader: loader,
            config: CameraMapViewConfig(
                center: const MapCoordinate(10, 106),
                zoom: 12,
                trafficEnabled: true,
                mapType: type,
                markers: const [
                  CameraMapMarker(
                      id: 'one',
                      position: MapCoordinate(10, 106),
                      title: 'Camera')
                ],
                onMapCreated: (value) => handle = value),
            nativeBuilder:
                (context, style, config, onCreated, onReady, onIdle) {
              nativeConfig = config;
              created = onCreated;
              ready = onReady;
              return const SizedBox(key: ValueKey('native'));
            }));
    await tester.pumpWidget(app(CameraMapType.street));
    await tester.pumpAndSettle();
    created(first);
    ready();
    await tester.pumpAndSettle();
    final oldReady = ready;
    final oldHandle = handle!;
    await tester.pumpWidget(app(CameraMapType.hybrid));
    await tester.pumpAndSettle();
    expect(nativeConfig.center.latitude, 10.8);
    expect(nativeConfig.zoom, 16);
    created(second);
    oldReady();
    await tester.pumpAndSettle();
    expect(second.markers, 0);
    ready();
    await tester.pumpAndSettle();
    expect(second.markers, 1);
    await oldHandle.moveTo(0, 0);
    expect(first.moves, 0);
    await tester.pumpWidget(app(CameraMapType.hybrid, active: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('native')), findsNothing);
    await handle!.moveTo(0, 0);
    expect(second.moves, 0);
  });
  testWidgets('denied auxiliary styles preserve street map and report failure',
      (tester) async {
    final loader = FakeLoader()..failAux = true;
    String? actual;
    await tester.pumpWidget(localized(CameraMapCanvas(
        styleLoader: loader,
        connectionConfig: const MapConnectionConfig(apiKey: 'test'),
        config: const CameraMapViewConfig(
            center: MapCoordinate(10, 106),
            zoom: 12,
            trafficEnabled: true,
            mapType: CameraMapType.hybrid,
            markers: []),
        nativeBuilder: (context, style, config, onCreated, onReady, onIdle) {
          actual = style;
          return const SizedBox();
        })));
    await tester.pumpAndSettle();
    expect(jsonDecode(actual!)['sources'], contains('tm'));
    expect(find.textContaining('Không tải được lớp'), findsOneWidget);
  });
  testWidgets('late previous style request cannot replace newer style',
      (tester) async {
    final loader = DelayedLoader();
    String? current;
    Widget app(CameraMapType type) => MaterialApp(
        home: CameraMapCanvas(
            styleLoader: loader,
            connectionConfig: const MapConnectionConfig(apiKey: 'test'),
            config: CameraMapViewConfig(
                center: const MapCoordinate(10, 106),
                zoom: 12,
                trafficEnabled: false,
                mapType: type,
                markers: const []),
            nativeBuilder:
                (context, style, config, onCreated, onReady, onIdle) {
              current = style;
              return const SizedBox();
            }));
    await tester.pumpWidget(app(CameraMapType.street));
    await tester.pumpWidget(app(CameraMapType.hybrid));
    await tester.pumpAndSettle();
    expect(jsonDecode(current!)['sources'], contains('hm'));
    loader.first.complete({
      'version': 8,
      'sources': {'stale': <String, dynamic>{}},
      'layers': <Object>[]
    });
    await tester.pumpAndSettle();
    expect(jsonDecode(current!)['sources'], contains('hm'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(CameraMapCanvas), matching: find.byType(Stack)),
        findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(jsonDecode(current!)['sources'], contains('hm'));
  });
}
