import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_viewer_screen.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import '../../support/camera_fakes.dart';

final pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
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
  final Map<String, List<Camera>> relatedById;

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
          {String? etag, CancelToken? cancelToken}) async =>
      Right(SnapshotReceived(SnapshotFrame(bytes: pngBytes, etag: 'e1')));
}

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'shared': {'retry': 'Thử lại', 'close': 'Đóng'},
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
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

  testWidgets('mode switcher switches content; Live on a snapshot-only '
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
    expect(find.byKey(const ValueKey('related_camera_cam-rel-2')),
        findsOneWidget);
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

    expect(find.byKey(const ValueKey('viewer_fullscreen_page')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('viewer_fullscreen_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('viewer_fullscreen_page')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
