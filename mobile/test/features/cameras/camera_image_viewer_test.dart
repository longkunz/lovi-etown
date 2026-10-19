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
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';
import 'package:dio/dio.dart';

class FakeViewerCameraRepository implements CameraRepository {
  final Camera camera = const Camera(
    id: 'cam-02',
    name: 'Vo Thi Sau - Tran Quoc Thao',
    provinceId: 'tp_hcm',
    district: 'Quan 3',
    playbackEndpoint: '/api/v1/playback/cam-02',
    snapshotEndpoint: '/api/v1/snapshot/cam-02',
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
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async => const Right([]);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async => Right(camera);

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async {
    return const Right(PlaybackDescriptor(
      cameraId: 'cam-02',
      kind: 'snapshot_poll',
      snapshotEndpoint: '/api/v1/snapshot/cam-02',
      refreshIntervalMs: 5000,
    ));
  }

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint, {String? etag, CancelToken? cancelToken}) async {
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
    return Right(SnapshotReceived(SnapshotFrame(bytes: dummyBytes)));
  }
}

class FakeViewerFavoritesRepository implements FavoritesRepository {
  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield const [];
  }

  @override
  FutureEither<void> load() async => const Right(null);

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async => const Right(null);

  @override
  FutureEither<void> resetCorruptData() async => const Right(null);
}

class ViewerTestAssetLoader extends AssetLoader {
  const ViewerTestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'shared': {
        'retry': 'Thử lại',
        'close': 'Đóng',
      },
      'camera': {
        'title': 'Camera giao thông',
      },
    };
  }
}

Widget buildTestApp({required Widget child}) {
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
    path: 'assets/translations',
    assetLoader: const ViewerTestAssetLoader(),
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

  group('CameraImageViewer', () {
    late FakeViewerCameraRepository repo;
    late FakeViewerFavoritesRepository favRepo;
    late CameraPreviewCubit previewCubit;

    setUp(() {
      repo = FakeViewerCameraRepository();
      favRepo = FakeViewerFavoritesRepository();
      previewCubit = CameraPreviewCubit(repository: repo);
    });

    tearDown(() {
      previewCubit.close();
    });

    testWidgets('back_closes_viewer_before_sheet', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showCameraSnapshotSheet(
                    context,
                    cameraId: 'cam-02',
                    preview: previewCubit,
                    favorites: favRepo,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraSnapshotSheet), findsOneWidget);

      // Open viewer
      await tester.tap(find.byKey(const ValueKey('snapshot_sheet_image')));
      await tester.pumpAndSettle();
      expect(find.byType(CameraImageViewer), findsOneWidget);

      // First back closes viewer
      final closeButton = find.byKey(const ValueKey('viewer_close_button'));
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Viewer closed, sheet STILL OPEN
      expect(find.byType(CameraImageViewer), findsNothing);
      expect(find.byType(CameraSnapshotSheet), findsOneWidget);

      // Second back closes sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Sheet closed
      expect(find.byType(CameraSnapshotSheet), findsNothing);
    });

    testWidgets('zoom_does_not_dismiss_sheet', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showCameraSnapshotSheet(
                    context,
                    cameraId: 'cam-02',
                    preview: previewCubit,
                    favorites: favRepo,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snapshot_sheet_image')));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Perform pan drag on viewer
      await tester.drag(
        find.byType(InteractiveViewer),
        const Offset(0, 100),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Viewer should still be open!
      expect(find.byType(CameraImageViewer), findsOneWidget);
    });
  });
}
