import 'dart:async';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_view_config.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_repository.dart';
import 'camera_screen_test.dart'
    show FakeScreenCameraRepository, FakeFavoritesRepository;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/routing/app_router.dart';
import 'package:flutter_starter/src/routing/app_routes.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_navigation_shell.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_map_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_boot_test.dart' show TestAssetLoader;

class NavigationMapRepository implements CameraMapRepository {
  @override
  FutureEither<CameraMapResult> search(CameraMapQuery query,
          {CancelToken? cancelToken}) async =>
      const Right(
          CameraMapResult(items: [], hasMore: false, catalogVersion: 'test'));
}

class NavigationCameraRepository extends FakeScreenCameraRepository {
  int lists = 0, snapshots = 0;
  @override
  FutureEither<CatalogPage> list(
      {String? query,
      String? district,
      int limit = 50,
      int offset = 0,
      CancelToken? cancelToken}) {
    lists++;
    return super.list(
        query: query,
        district: district,
        limit: limit,
        offset: offset,
        cancelToken: cancelToken);
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      Right(PlaybackDescriptor(
          cameraId: id,
          kind: 'snapshot_poll',
          snapshotEndpoint: '/snapshot/$id',
          refreshIntervalMs: 12000));
  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
      {String? etag, CancelToken? cancelToken}) async {
    snapshots++;
    return const Right(SnapshotUnchanged());
  }
}

class NativeMapProbe extends StatefulWidget {
  const NativeMapProbe(
      {required this.config,
      required this.onMounted,
      required this.onDisposed,
      super.key});
  final CameraMapViewConfig config;
  final VoidCallback onMounted, onDisposed;
  @override
  State<NativeMapProbe> createState() => _NativeMapProbeState();
}

class _NativeMapProbeState extends State<NativeMapProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMounted();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.config.onIdle?.call(const MapBounds(106.6, 10.7, 106.8, 10.9),
            13, const MapCoordinate(10.7769, 106.7009));
      }
    });
  }

  @override
  void dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() {
    AppConfig.cameraConfig = const CameraConnectionConfig(
        baseUrl: '', readerKey: '', demoMode: true);
  });
  Future<void> boot(WidgetTester tester, {String? location}) async {
    final router = createAppRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        initialLocation: location ?? AppRoutes.map,
        cameraRepository: FakeScreenCameraRepository(),
        favoritesRepository: FakeFavoritesRepository(),
        mapRepository: NavigationMapRepository());
    addTearDown(router.dispose);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const TestAssetLoader(),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: Builder(
            builder: (context) => MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'cold start opens map first and does not create the camera catalog',
      (tester) async {
    await boot(tester);
    expect(find.byType(CameraNavigationShell), findsOneWidget);
    expect(find.byType(CameraMapScreen), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(bar.destinations.map((w) => (w as NavigationDestination).label),
        ['Bản đồ', 'Camera']);
    expect(find.byType(CameraScreen), findsNothing);
  });
  testWidgets('explicit camera deep link selects second tab', (tester) async {
    await boot(tester, location: '/cameras');
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    await tester.tap(find.text('Bản đồ').last);
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    await tester.tap(find.text('Camera').last);
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
  });
  testWidgets(
      'legacy map link redirects to map and repeat tab taps preserve page',
      (tester) async {
    await boot(tester, location: '/map');
    final state = tester.state(find.byType(CameraMapScreen));
    await tester.tap(find.text('Bản đồ').last);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(CameraMapScreen)), same(state));
  });
  testWidgets(
      'real shell releases hidden map and lazily preserves catalog across tab and root viewer changes',
      (tester) async {
    final repo = NavigationCameraRepository();
    int maps = 0;
    final router = createAppRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        cameraRepository: repo,
        favoritesRepository: FakeFavoritesRepository(),
        mapRepository: NavigationMapRepository(),
        mapBuilder: (context, config) => NativeMapProbe(
            config: config, onMounted: () => maps++, onDisposed: () => maps--));
    addTearDown(router.dispose);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const TestAssetLoader(),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: Builder(
            builder: (context) => MaterialApp.router(
                routerConfig: router,
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales))));
    await tester.pumpAndSettle();
    expect(maps, 1);
    expect(repo.lists, 0);
    expect(repo.snapshots, 0);
    await tester.tap(find.text('Camera').last);
    await tester.pumpAndSettle();
    expect(maps, 0);
    expect(repo.lists, 1);
    final catalogState = tester.state(find.byType(CameraScreen));
    await tester.tap(find.text('Bản đồ').last);
    await tester.pumpAndSettle();
    expect(maps, 1);
    unawaited(router.push('/camera/00000000-0000-0000-0000-000000000001'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(maps, 0);
    router.pop();
    await tester.pumpAndSettle();
    expect(maps, 1);
    await tester.tap(find.text('Camera').last);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(CameraScreen)), same(catalogState));
    expect(repo.lists, 1);
    await tester.pumpWidget(const SizedBox());
    expect(maps, 0);
  });
}
