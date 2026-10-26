// T03 / AC3 — App-to-backend smoke test (REAL repository, NOT demo mode).
//
// Unlike camera_flow_test.dart (demoMode + FakeIntegrationCameraRepository),
// this test talks to a real running backend through ApiCameraRepository:
//   list -> detail -> playback descriptor -> snapshot (200) -> snapshot (304)
//
// Prerequisites (see README-AC3-VI.md in this bundle):
//   - Backend running in fixture provider mode, seeded with
//     backend/fixtures/catalog.json (e.g. "Camera Cầu Sài Gòn").
//   - Backend reachable from the device/emulator:
//       Android emulator : http://10.0.2.2:3000  (host loopback alias)
//       Physical device  : run `adb reverse tcp:3000 tcp:3000` first,
//                          then use http://127.0.0.1:3000
//   - Reader key below must equal the backend's BACKEND_API_KEY.
//
// Run:
//   flutter test integration_test/camera_backend_smoke_test.dart \
//     --dart-define=T03_BACKEND_URL=http://10.0.2.2:3000 \
//     --dart-define=T03_READER_KEY=<backend BACKEND_API_KEY>
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/api_camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_viewer_screen.dart';
import 'package:flutter_starter/src/services/camera_api_client.dart';
import 'package:flutter_starter/src/theme/theme.dart';
import '../test/support/camera_fakes.dart';

const _backendUrl = String.fromEnvironment(
  'T03_BACKEND_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _readerKey = String.fromEnvironment('T03_READER_KEY');
const _cameraQuery = String.fromEnvironment('T03_CAMERA_QUERY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ApiCameraRepository repo;
  late String smokeCameraId;

  setUpAll(() async {
    EasyLocalization.logger.enableLevels = [];
    await AppConfig.init(
      config: const CameraConnectionConfig(
        baseUrl: _backendUrl,
        readerKey: _readerKey,
        demoMode: false,
      ),
    );
    repo = ApiCameraRepository(
      apiClient: CameraApiClient(
        dio: AppConfig.dio,
        config: AppConfig.cameraConfig,
      ),
    );
    final page = (await repo.list(
      query: _cameraQuery.isEmpty ? null : _cameraQuery,
      limit: 10,
    ))
        .getOrElse((failure) => throw StateError(
              'smoke camera lookup failed: ${failure.message}',
            ));
    smokeCameraId = page.items
        .firstWhere(
          (camera) => camera.snapshotCapable,
          orElse: () => throw StateError('No snapshot-capable smoke camera'),
        )
        .id;
  });

  test('AC3 API path: list/detail/playback/snapshot 200 then 304', () async {
    expect(_readerKey, isNotEmpty,
        reason: 'Pass --dart-define=T03_READER_KEY=<BACKEND_API_KEY>');

    // 1. List — real catalog from the seeded backend.
    final pageResult = await repo.list(
      query: _cameraQuery.isEmpty ? null : _cameraQuery,
      limit: 10,
    );
    final page = pageResult.getOrElse(
      (f) => throw StateError('list failed: ${f.message}'),
    );
    expect(page.items, isNotEmpty,
        reason: 'Backend catalog is empty — did seed:fixture run?');
    final camera = page.items.firstWhere((c) => c.id == smokeCameraId);

    // 2. Detail — same camera id round-trips.
    final detailResult = await repo.detail(camera.id);
    final detail = detailResult.getOrElse(
      (f) => throw StateError('detail failed: ${f.message}'),
    );
    expect(detail.id, camera.id);

    // 3. Playback descriptor — gives the snapshot endpoint used below.
    final playbackResult = await repo.playback(camera.id);
    final descriptor = playbackResult.getOrElse(
      (f) => throw StateError('playback failed: ${f.message}'),
    );
    expect(descriptor.snapshotEndpoint, isNotEmpty);

    // 4. Snapshot, first call — 200 with decodable bytes + ETag.
    //    (Since T01 the client decode-validates the payload, so a
    //    SnapshotReceived here also proves the bytes are a real image.)
    final firstResult = await repo.snapshot(descriptor.snapshotEndpoint);
    final first = firstResult.getOrElse(
      (f) => throw StateError('snapshot #1 failed: ${f.message}'),
    );
    expect(first, isA<SnapshotReceived>());
    final frame = (first as SnapshotReceived).frame;
    expect(frame.bytes, isNotEmpty);
    expect(frame.etag, isNotNull);
    expect(frame.etag, isNotEmpty);

    // 5. Snapshot, second call with the ETag — backend answers 304,
    //    which the client maps to SnapshotUnchanged.
    final secondResult = await repo.snapshot(
      descriptor.snapshotEndpoint,
      etag: frame.etag,
    );
    final second = secondResult.getOrElse(
      (f) => throw StateError('snapshot #2 failed: ${f.message}'),
    );
    expect(second, isA<SnapshotUnchanged>(),
        reason: 'Expected 304/SnapshotUnchanged for a matching ETag');
  });

  testWidgets('AC3 UI path: backend camera renders in camera viewer',
      (tester) async {
    final favRepo = InMemoryFavoritesRepository();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: buildLightTheme(primaryColorHex: '#00897B'),
              home: CameraViewerScreen(
                cameraId: smokeCameraId,
                repository: repo,
                favoritesRepository: favRepo,
              ),
            );
          },
        ),
      ),
    );

    // Real network + polling timers: pump in steps instead of
    // pumpAndSettle, which never settles while preview polling is armed.
    for (var i = 0;
        i < 20 &&
            find
                .byKey(const ValueKey('viewer_snapshot_image'))
                .evaluate()
                .isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(CameraViewerScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('viewer_snapshot_image')),
      findsOneWidget,
    );
  });
}
