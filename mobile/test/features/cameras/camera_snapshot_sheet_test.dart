import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_image_viewer.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';
import 'package:dio/dio.dart';

class FakeSheetCameraRepository implements CameraRepository {
  /// Optional per-test override for snapshot behaviour (T02 tests).
  FutureEither<SnapshotReply> Function()? snapshotHandler;

  final Camera camera = const Camera(
    id: 'cam-01',
    name: 'Giao lo Le Loi - Pasteur',
    provinceId: 'tp_hcm',
    district: 'Quan 1',
    address: 'Quan 1, TP.HCM',
    snapshotCapable: true,
    playbackEndpoint: '/api/v1/playback/cam-01',
    snapshotEndpoint: '/api/v1/snapshot/cam-01',
  );

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    return Right(CatalogPage(
      items: [camera],
      limit: limit,
      offset: offset,
      total: 1,
      catalogVersion: 'v1',
      isStale: false,
      dataMode: 'fixture',
    ));
  }

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async {
    return const Right([]);
  }

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async {
    return Right(camera);
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async {
    return const Right(PlaybackDescriptor(
      cameraId: 'cam-01',
      kind: 'snapshot_poll',
      snapshotEndpoint: '/api/v1/snapshot/cam-01',
      refreshIntervalMs: 5000,
    ));
  }

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint, {String? etag, CancelToken? cancelToken}) async {
    if (snapshotHandler != null) return snapshotHandler!();
    // 1x1 transparent png / dummy bytes
    final dummyBytes = Uint8List.fromList([
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
    return Right(SnapshotReceived(SnapshotFrame(bytes: dummyBytes, etag: 'etag-1')));
  }
}

class FakeSheetFavoritesRepository implements FavoritesRepository {
  final List<FavoriteCamera> _favs = [];

  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield List.unmodifiable(_favs);
  }

  @override
  FutureEither<void> load() async => const Right(null);

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async {
    if (saved) {
      _favs.add(FavoriteCamera(
        id: camera.id,
        name: camera.name,
        district: camera.district,
        address: camera.address,
        addedAt: DateTime.now(),
      ));
    } else {
      _favs.removeWhere((f) => f.id == camera.id);
    }
    return const Right(null);
  }

  @override
  FutureEither<void> resetCorruptData() async => const Right(null);
}

class SheetTestAssetLoader extends AssetLoader {
  const SheetTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'shared': {
        'retry': 'Thử lại',
        'close': 'Đóng',
      },
      'camera': {
        'title': 'Camera giao thông',
        'favorites_title': 'Quan tâm',
      },
    };
  }
}

Widget buildTestApp({required Widget child}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
    path: 'assets/translations',
    assetLoader: const SheetTestAssetLoader(),
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

  group('CameraSnapshotSheet', () {
    late FakeSheetCameraRepository repo;
    late FakeSheetFavoritesRepository favRepo;
    late CameraPreviewCubit previewCubit;

    setUp(() {
      repo = FakeSheetCameraRepository();
      favRepo = FakeSheetFavoritesRepository();
      previewCubit = CameraPreviewCubit(repository: repo);
    });

    tearDown(() {
      previewCubit.close();
    });

    testWidgets('sheet_has_no_refresh_fullscreen_buttons_or_time_text', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showCameraSnapshotSheet(
                    context,
                    cameraId: 'cam-01',
                    preview: previewCubit,
                    favorites: favRepo,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Should show sheet title and close button
      expect(find.byType(CameraSnapshotSheet), findsOneWidget);
      expect(find.text('Giao lo Le Loi - Pasteur'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Should NOT have refresh button, fullscreen button, or live clock text
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
      expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
      // No live clock or timestamp labels (timestamp is in JPEG image itself)
      expect(find.textContaining('Cập nhật lúc'), findsNothing);
      expect(find.textContaining('giây trước'), findsNothing);
    });

    testWidgets(
        'refresh_error_shows_stale_badge_and_keeps_image_T02', (tester) async {
      final dummyBytes = Uint8List.fromList([
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
      var snapshotCalls = 0;
      repo.snapshotHandler = () async {
        snapshotCalls++;
        if (snapshotCalls == 1) {
          return Right(SnapshotReceived(
              SnapshotFrame(bytes: dummyBytes, etag: 'etag-1')));
        }
        return const Left(
            ApiFailure('Mất mạng', statusCode: 503, retryable: true));
      };

      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showCameraSnapshotSheet(
                    context,
                    cameraId: 'cam-01',
                    preview: previewCubit,
                    favorites: favRepo,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // First frame loaded; no stale notice yet.
      expect(find.byKey(const ValueKey('snapshot_sheet_image')),
          findsOneWidget);
      expect(find.text('Ảnh cũ'), findsNothing);

      // Descriptor refresh interval is 5s: advance past it so the poll
      // runs and fails, well before any 60s age threshold.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump();

      // The good image is still shown and is now visibly marked stale,
      // without calling the network error "camera offline".
      expect(find.byKey(const ValueKey('snapshot_sheet_image')),
          findsOneWidget);
      expect(find.text('Ảnh cũ'), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets('tap_image_opens_viewer_with_same_preview', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showCameraSnapshotSheet(
                    context,
                    cameraId: 'cam-01',
                    preview: previewCubit,
                    favorites: favRepo,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap snapshot image area
      final imageFinder = find.byKey(const ValueKey('snapshot_sheet_image'));
      expect(imageFinder, findsOneWidget);
      await tester.tap(imageFinder);
      await tester.pumpAndSettle();

      // CameraImageViewer should now be open
      expect(find.byType(CameraImageViewer), findsOneWidget);
      expect(find.text('Giao lo Le Loi - Pasteur'), findsWidgets);
    });

    testWidgets('large_font_small_viewport_no_overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 500 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 500),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showCameraSnapshotSheet(
                      context,
                      cameraId: 'cam-01',
                      preview: previewCubit,
                      favorites: favRepo,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CameraSnapshotSheet), findsOneWidget);
    });
  });
}
