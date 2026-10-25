import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/services/storage_service.dart';
import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import '../../support/fake_video_platform.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_viewer_screen.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import '../../support/camera_fakes.dart';

final pngBytes = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

const liveCam = Camera(
  id: 'cam-live',
  name: 'Mai Chí Thọ - Lương Định Của',
  provinceId: 'tp_hcm',
  district: 'Quan 2',
  address: 'Mai Chí Thọ, Quan 2',
  snapshotCapable: true,
  playbackEndpoint: '/v1/cameras/cam-live/playback',
  snapshotEndpoint: '/v1/cameras/cam-live/snapshot',
  latitude: 10.7726,
  longitude: 106.6911,
  liveCapable: true,
  streamUrl: 'http://125.234.114.126:11984/api/stream.m3u8?src=x',
);

const plainCam = Camera(
  id: 'cam-plain',
  name: 'Nam Kỳ Khởi Nghĩa - Lý Tự Trọng',
  provinceId: 'tp_hcm',
  district: 'Quan 1',
  snapshotCapable: true,
  playbackEndpoint: '/v1/cameras/cam-plain/playback',
  snapshotEndpoint: '/v1/cameras/cam-plain/snapshot',
);

const relCam1 = Camera(
  id: 'cam-rel-1',
  name: 'Camera Liên Quan Một',
  provinceId: 'tp_hcm',
  district: 'Quan 1',
  snapshotCapable: true,
  playbackEndpoint: '/v1/cameras/cam-rel-1/playback',
  snapshotEndpoint: '/v1/cameras/cam-rel-1/snapshot',
);

const relCam2 = Camera(
  id: 'cam-rel-2',
  name: 'Camera Liên Quan Hai',
  provinceId: 'tp_hcm',
  district: 'Quan 1',
  snapshotCapable: true,
  playbackEndpoint: '/v1/cameras/cam-rel-2/playback',
  snapshotEndpoint: '/v1/cameras/cam-rel-2/snapshot',
);

class _ViewerRepo implements CameraRepository {
  _ViewerRepo({
    required this.cameras,
    this.relatedById = const {},
  });

  final Map<String, Camera> cameras;
  final List<String> snapshotRequests = [];
  final Map<String, List<Camera>> relatedById;
  bool returnUnchanged = false;

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      Right(CatalogPage(
        items: cameras.values.toList(),
        limit: limit,
        offset: offset,
        total: cameras.length,
        catalogVersion: 'v1',
        dataMode: 'fixture',
      ));

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      const Right([
        DistrictOption(name: 'Quan 1', count: 3),
        DistrictOption(name: 'Quan 2', count: 1),
      ]);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      Right(cameras[id] ?? cameras.values.first);

  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      Right(relatedById[id] ?? const []);

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      Right(PlaybackDescriptor(
        cameraId: id,
        kind: 'snapshot_poll',
        snapshotEndpoint: '/v1/cameras/$id/snapshot',
        refreshIntervalMs: 60000,
      ));

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
      {String? etag, CancelToken? cancelToken}) async {
    snapshotRequests.add(endpoint);
    if (returnUnchanged) return const Right(SnapshotUnchanged());
    return Right(SnapshotReceived(SnapshotFrame(bytes: pngBytes, etag: 'e1')));
  }
}

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'shared': {'retry': 'Thử lại', 'close': 'Đóng'},
        'camera': {
          'traffic_map_title': 'Bản đồ lưu lượng',
          'traffic_map_toggle': 'Bật/tắt lưu lượng giao thông',
          'traffic_map_fullscreen': 'Xem bản đồ toàn màn hình',
          'traffic_map_recenter': 'Về vị trí camera',
          'traffic_map_no_location': 'Chưa có dữ liệu vị trí cho camera này',
        },
      };
}

Widget _app({
  required String cameraId,
  required _ViewerRepo repo,
  required InMemoryFavoritesRepository favs,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
    path: 'assets/translations',
    assetLoader: const _Loader(),
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    saveLocale: false,
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: CameraViewerScreen(
          cameraId: cameraId,
          repository: repo,
          favoritesRepository: favs,
        ),
      ),
    ),
  );
}

Set<bool> _selectedModes(WidgetTester tester) {
  final button = tester.widget<SegmentedButton<bool>>(
    find.byKey(const ValueKey('viewer_mode_switcher')),
  );
  return button.selected;
}

class _DelayedFavorites extends InMemoryFavoritesRepository {
  final loadResult = Completer<Either<Failure, List<FavoriteCamera>>>();
  bool retry = false;

  @override
  FutureEither<List<FavoriteCamera>> load() async {
    if (retry) return const Right([]);
    return loadResult.future;
  }
}

Widget _featureApp({Widget? home, GoRouter? router}) => EasyLocalization(
      supportedLocales: const [Locale('vi')],
      path: 'assets/translations',
      assetLoader: const _Loader(),
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'),
      saveLocale: false,
      child: Builder(
          builder: (context) => router == null
              ? MaterialApp(
                  home: home,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale)
              : MaterialApp.router(
                  routerConfig: router,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale)),
    );

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await StorageService.instance.init();
    AppConfig.cameraConfig = const CameraConnectionConfig(
      baseUrl: '',
      readerKey: '',
      demoMode: true,
    );
  });

  Future<void> pumpViewer(
    WidgetTester tester, {
    required String cameraId,
    required _ViewerRepo repo,
    required InMemoryFavoritesRepository favs,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(_app(cameraId: cameraId, repo: repo, favs: favs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('snapshot countdown animates and restarts after a 304 refresh',
      (tester) async {
    final repo = _ViewerRepo(cameras: {'cam-plain': plainCam});
    await pumpViewer(tester,
        cameraId: 'cam-plain', repo: repo, favs: InMemoryFavoritesRepository());

    final progress = find.byKey(const ValueKey('camera_refresh_progress'));
    expect(progress, findsOneWidget);
    final start = tester.widget<CircularProgressIndicator>(progress).value!;
    await tester.pump(const Duration(seconds: 6));
    final later = tester.widget<CircularProgressIndicator>(progress).value!;
    expect(later, lessThan(start - 0.09));
    expect(find.text('Làm mới sau 54s'), findsOneWidget);
    expect(repo.snapshotRequests, hasLength(1));

    repo.returnUnchanged = true;
    await tester.pump(const Duration(seconds: 54));
    await tester.pump();
    expect(repo.snapshotRequests, hasLength(2));
    expect(find.text('Làm mới sau 60s'), findsOneWidget);
    expect(tester.widget<CircularProgressIndicator>(progress).value!,
        greaterThan(0.99));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(progress, findsNothing);
    await tester.pump(const Duration(seconds: 90));
    expect(repo.snapshotRequests, hasLength(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(repo.snapshotRequests, hasLength(3));
    expect(progress, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opens in Live mode for a live-capable camera', (tester) async {
    final repo = _ViewerRepo(cameras: {'cam-live': liveCam});
    await pumpViewer(
      tester,
      cameraId: 'cam-live',
      repo: repo,
      favs: InMemoryFavoritesRepository(),
    );

    // The test environment has no video platform, so the player cannot
    // initialize. The fallback note proves the viewer opened in Live
    // mode (a snapshot-first open would never attempt playback) and
    // then fell back to the snapshot, like the sheet does.
    expect(
      find.text('Không phát được trực tiếp — đang hiện ảnh tĩnh'),
      findsOneWidget,
    );
    expect(_selectedModes(tester), {false});
    expect(find.byKey(const ValueKey('viewer_snapshot_image')), findsOneWidget);
    expect(find.text('Mai Chí Thọ - Lương Định Của'), findsWidgets);
    // District chip + LIVE badge in the info section.
    expect(find.text('Quan 2'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opens in Snapshot mode for a snapshot-only camera',
      (tester) async {
    final repo = _ViewerRepo(cameras: {'cam-plain': plainCam});
    await pumpViewer(
      tester,
      cameraId: 'cam-plain',
      repo: repo,
      favs: InMemoryFavoritesRepository(),
    );

    expect(_selectedModes(tester), {false});
    expect(find.byKey(const ValueKey('viewer_snapshot_image')), findsOneWidget);
    expect(
      find.text('Camera này không có luồng trực tiếp'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'mode switcher switches content; Live on a snapshot-only '
      'camera keeps the snapshot with a note', (tester) async {
    final repo = _ViewerRepo(cameras: {'cam-plain': plainCam});
    await pumpViewer(
      tester,
      cameraId: 'cam-plain',
      repo: repo,
      favs: InMemoryFavoritesRepository(),
    );

    await tester.tap(find.text('Trực tiếp'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_selectedModes(tester), {true});
    expect(
      find.text('Camera này không có luồng trực tiếp'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('viewer_snapshot_image')), findsOneWidget);

    await tester.tap(find.text('Ảnh'));
    await tester.pump();
    expect(_selectedModes(tester), {false});
    expect(
      find.text('Camera này không có luồng trực tiếp'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('mode switcher on a live camera switches back to the snapshot',
      (tester) async {
    final repo = _ViewerRepo(cameras: {'cam-live': liveCam});
    await pumpViewer(
      tester,
      cameraId: 'cam-live',
      repo: repo,
      favs: InMemoryFavoritesRepository(),
    );

    await tester.tap(find.text('Ảnh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_selectedModes(tester), {false});
    expect(find.byKey(const ValueKey('viewer_snapshot_image')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('related cameras render and tapping one opens its viewer',
      (tester) async {
    final repo = _ViewerRepo(
      cameras: {
        'cam-plain': plainCam,
        'cam-rel-1': relCam1,
        'cam-rel-2': relCam2,
      },
      relatedById: const {
        'cam-plain': [relCam1, relCam2],
      },
    );
    await pumpViewer(
      tester,
      cameraId: 'cam-plain',
      repo: repo,
      favs: InMemoryFavoritesRepository(),
    );

    final relatedCard = find.byKey(const ValueKey('related_camera_cam-rel-1'));
    // Scroll the outer (vertical) scroll view down to the related row;
    // scrollUntilVisible cannot pick a scrollable here because the
    // viewer has two (outer vertical + the horizontal related list).
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(relatedCard, findsOneWidget);
    expect(
        find.byKey(const ValueKey('related_camera_cam-rel-2')), findsOneWidget);
    expect(find.text('Camera Liên Quan Một'), findsWidgets);

    await tester.tap(relatedCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    // The pushed viewer is the only on-stage viewer and shows the
    // related camera.
    expect(find.byType(CameraViewerScreen), findsOneWidget);
    expect(find.text('Camera Liên Quan Một'), findsWidgets);
    final titleFinder = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Camera Liên Quan Một'),
    );
    expect(titleFinder, findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('favorite toggle saves and unsaves the camera', (tester) async {
    final repo = _ViewerRepo(cameras: {'cam-plain': plainCam});
    final favs = InMemoryFavoritesRepository();
    addTearDown(favs.dispose);
    await pumpViewer(tester, cameraId: 'cam-plain', repo: repo, favs: favs);

    final toggle = find.byKey(const ValueKey('viewer_favorite_button'));
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await favs.load();
    expect(saved.getOrElse((_) => []).map((f) => f.id), ['cam-plain']);
    expect(
      find.descendant(of: toggle, matching: find.byIcon(Icons.star)),
      findsOneWidget,
    );

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final afterUnsaved = await favs.load();
    expect(afterUnsaved.getOrElse((_) => []), isEmpty);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fullscreen toggle opens the full-screen media page',
      (tester) async {
    final repo = _ViewerRepo(cameras: {'cam-plain': plainCam});
    await pumpViewer(
      tester,
      cameraId: 'cam-plain',
      repo: repo,
      favs: InMemoryFavoritesRepository(),
    );

    await tester.tap(find.byKey(const ValueKey('viewer_fullscreen_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
        find.byKey(const ValueKey('viewer_fullscreen_page')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('viewer_fullscreen_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('viewer_fullscreen_page')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deep-link save preserves existing favorites', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await StorageService.instance.clear();
    final seed = resolveFavoritesRepository(null);
    await seed.load();
    await seed.setSaved(plainCam, true);
    final repo = _ViewerRepo(cameras: {relCam1.id: relCam1});
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);
    await tester.pumpWidget(_featureApp(
      home: ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (_, __, ___) => CameraViewerFeature(
          cameraId: relCam1.id,
          cameraRepository: repo,
        ),
      ),
    ));
    await _pumpFrames(tester);
    rebuild.value++;
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_favorite_button')));
    await _pumpFrames(tester);
    final payload =
        jsonDecode(StorageService.instance.getString('camera_favorites_v1')!)
            as Map<String, dynamic>;
    final ids = (payload['items'] as List).map((item) => item['id']).toList();
    await tester.pumpWidget(const SizedBox());
    expect(ids, containsAll(['cam-plain', 'cam-rel-1']));
  });

  testWidgets('favorites load gates saving and can retry a failure',
      (tester) async {
    final favs = _DelayedFavorites();
    addTearDown(favs.dispose);
    final repo = _ViewerRepo(cameras: {plainCam.id: plainCam});
    await tester.pumpWidget(_featureApp(
        home: CameraViewerFeature(
            cameraId: plainCam.id,
            cameraRepository: repo,
            favoritesRepository: favs)));
    await _pumpFrames(tester);
    expect(find.byKey(const ValueKey('viewer_favorite_button')), findsNothing);
    favs.loadResult.complete(const Left(DatabaseFailure('read failed')));
    await _pumpFrames(tester);
    expect(find.text('read failed'), findsOneWidget);
    favs.retry = true;
    await tester.tap(find.byKey(const ValueKey('viewer_favorites_retry')));
    await _pumpFrames(tester);
    expect(
        find.byKey(const ValueKey('viewer_favorite_button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('same-route camera ID change replaces the displayed camera',
      (tester) async {
    final repo =
        _ViewerRepo(cameras: {plainCam.id: plainCam, relCam1.id: relCam1});
    final favs = InMemoryFavoritesRepository();
    addTearDown(favs.dispose);
    final router = GoRouter(initialLocation: '/camera/cam-plain', routes: [
      GoRoute(
          path: '/camera/:id',
          builder: (context, state) => CameraViewerFeature(
              cameraId: state.pathParameters['id']!,
              cameraRepository: repo,
              favoritesRepository: favs)),
    ]);
    await tester.pumpWidget(_featureApp(router: router));
    await _pumpFrames(tester);
    router.go('/camera/cam-rel-1');
    await _pumpFrames(tester);
    final title = tester
        .widget<Text>(find
            .descendant(of: find.byType(AppBar), matching: find.byType(Text))
            .first)
        .data;
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    expect(title, 'Camera Liên Quan Một');
  });

  testWidgets('covered camera stops polling and resumes on return',
      (tester) async {
    final repo = _ViewerRepo(cameras: {
      plainCam.id: plainCam,
      relCam1.id: relCam1
    }, relatedById: {
      plainCam.id: [relCam1]
    });
    await pumpViewer(tester,
        cameraId: plainCam.id, repo: repo, favs: InMemoryFavoritesRepository());
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -600));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('related_camera_cam-rel-1')));
    await _pumpFrames(tester);
    repo.snapshotRequests.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester);
    await tester.pump(const Duration(seconds: 61));
    await _pumpFrames(tester);
    final hiddenRequests = List.of(repo.snapshotRequests);
    Navigator.of(tester.element(find.byType(CameraViewerScreen))).pop();
    await _pumpFrames(tester);
    repo.snapshotRequests.clear();
    await tester.pump(const Duration(seconds: 61));
    await _pumpFrames(tester);
    final resumedRequests = List.of(repo.snapshotRequests);
    await tester.pumpWidget(const SizedBox());
    expect(hiddenRequests, isNot(contains('/v1/cameras/cam-plain/snapshot')));
    expect(hiddenRequests, contains('/v1/cameras/cam-rel-1/snapshot'));
    expect(resumedRequests, contains('/v1/cameras/cam-plain/snapshot'));
  });

  testWidgets('covered live camera pauses and resumes on return',
      (tester) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
    final repo = _ViewerRepo(cameras: {
      liveCam.id: liveCam,
      relCam1.id: relCam1
    }, relatedById: {
      liveCam.id: [relCam1]
    });
    await pumpViewer(tester,
        cameraId: liveCam.id, repo: repo, favs: InMemoryFavoritesRepository());
    expect(platform.playing.length, 1);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -650));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('related_camera_cam-rel-1')));
    await _pumpFrames(tester);
    final coveredCount = platform.playing.length;
    Navigator.of(tester.element(find.byType(CameraViewerScreen))).pop();
    await _pumpFrames(tester);
    final resumedCount = platform.playing.length;
    await tester.pumpWidget(const SizedBox());
    expect(coveredCount, 0);
    expect(resumedCount, 1);
  });

  testWidgets('fullscreen keeps only one live player playing', (tester) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
    final repo = _ViewerRepo(cameras: {liveCam.id: liveCam});
    await pumpViewer(tester,
        cameraId: liveCam.id, repo: repo, favs: InMemoryFavoritesRepository());
    expect(platform.playing.length, 1);
    await tester.tap(find.byKey(const ValueKey('viewer_fullscreen_button')));
    await _pumpFrames(tester);
    final fullscreenCount = platform.playing.length;
    await tester.tap(find.byKey(const ValueKey('viewer_fullscreen_close')));
    await tester.pump();
    final closingCount = platform.playing.length;
    await _pumpFrames(tester);
    await tester.pumpAndSettle();
    final resumedCount = platform.playing.length;
    await tester.pumpWidget(const SizedBox());
    expect(fullscreenCount, 1);
    expect(closingCount, 1);
    expect(resumedCount, 1);
  });

  testWidgets('snapshot fullscreen keeps refreshing the shared preview',
      (tester) async {
    final repo = _ViewerRepo(cameras: {plainCam.id: plainCam});
    await pumpViewer(tester,
        cameraId: plainCam.id, repo: repo, favs: InMemoryFavoritesRepository());
    await tester.tap(find.byKey(const ValueKey('viewer_fullscreen_button')));
    await _pumpFrames(tester);
    repo.snapshotRequests.clear();
    await tester.pump(const Duration(seconds: 61));
    await _pumpFrames(tester);
    final requests = List.of(repo.snapshotRequests);
    await tester.pumpWidget(const SizedBox());
    expect(requests, ['/v1/cameras/cam-plain/snapshot']);
  });
}
