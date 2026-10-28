import 'localized_widget_test_helper.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/data/models/camera_dto.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

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

Camera liveCam(
        {bool live = true,
        String? url = 'http://125.234.114.126:11984/api/stream.m3u8?src=x'}) =>
    Camera(
      id: 'cam-live',
      name: 'Mai Chí Thọ - Lương Định Của',
      provinceId: 'tp_hcm',
      snapshotCapable: true,
      playbackEndpoint: '/v1/cameras/cam-live/playback',
      snapshotEndpoint: '/v1/cameras/cam-live/snapshot',
      liveCapable: live,
      streamUrl: url,
    );

void main() {
  group('CameraDto live parsing (T14)', () {
    test('live capability + streamUrl -> canLive camera', () {
      final dto = CameraDto.fromJson({
        'id': 'cam-live',
        'name': 'X',
        'provinceId': 'tp_hcm',
        'capabilities': {'snapshot': true, 'live': true},
        'streamUrl': 'http://media.example/api/stream.m3u8?src=x',
      });
      final camera = dto.toDomain();
      expect(camera.liveCapable, isTrue);
      expect(camera.streamUrl, 'http://media.example/api/stream.m3u8?src=x');
      expect(camera.canLive, isTrue);
    });

    test('streamUrl is dropped when the API does not flag live', () {
      final dto = CameraDto.fromJson({
        'id': 'cam-plain',
        'name': 'Y',
        'provinceId': 'tp_hcm',
        'capabilities': {'snapshot': true, 'live': false},
        'streamUrl': 'http://media.example/api/stream.m3u8?src=x',
      });
      final camera = dto.toDomain();
      expect(camera.liveCapable, isFalse);
      expect(camera.streamUrl, isNull);
      expect(camera.canLive, isFalse);
    });

    test('live flag without a URL -> cannot play live', () {
      final dto = CameraDto.fromJson({
        'id': 'cam-half',
        'name': 'Z',
        'provinceId': 'tp_hcm',
        'capabilities': {'snapshot': true, 'live': true},
        'streamUrl': null,
      });
      expect(dto.toDomain().canLive, isFalse);
    });
  });

  group('snapshot sheet live toggle', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
    });

    Future<void> openSheet(WidgetTester tester, Camera camera) async {
      final preview = CameraPreviewCubit(repository: _Repo(camera));
      addTearDown(preview.close);
      await tester.pumpWidget(_app(preview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('toggle shows for a live camera, hidden for snapshot-only',
        (tester) async {
      await openSheet(tester, liveCam());
      expect(find.byKey(const ValueKey('live_mode_toggle')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await openSheet(tester, liveCam(live: false, url: null));
      expect(find.byKey(const ValueKey('live_mode_toggle')), findsNothing);
    });

    testWidgets(
        'a stream that cannot initialize falls back to the snapshot with a note',
        (tester) async {
      await openSheet(tester, liveCam());
      await tester.tap(find.text('Trực tiếp'));
      // The test environment has no video platform: initialization fails
      // and the sheet must fall back to the snapshot view with a note.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Không phát được trực tiếp — đang hiện ảnh tĩnh'),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey('snapshot_sheet_image')), findsOneWidget);
    });
  });
}

class _Repo implements CameraRepository {
  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  _Repo(this.camera);
  final Camera camera;

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      Right(CatalogPage(
        items: [camera],
        limit: limit,
        offset: offset,
        total: 1,
        catalogVersion: 'v1',
        dataMode: 'fixture',
      ));

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      Right(camera);

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      Right(PlaybackDescriptor(
        cameraId: camera.id,
        kind: 'snapshot_poll',
        snapshotEndpoint: camera.snapshotEndpoint!,
        refreshIntervalMs: 60000,
      ));

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
          {String? etag, CancelToken? cancelToken}) async =>
      Right(SnapshotReceived(SnapshotFrame(bytes: pngBytes, etag: 'e1')));
}

class _Favs implements FavoritesRepository {
  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield const [];
  }

  @override
  FutureEither<void> load() async => const Right(null);

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async =>
      const Right(null);

  @override
  FutureEither<void> resetCorruptData() async => const Right(null);
}

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'shared': {'retry': 'Thử lại', 'close': 'Đóng'},
        'camera': {
          ...cameraTestTranslations,
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
      };
}

Widget _app(CameraPreviewCubit preview) {
  final favs = _Favs();
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
        home: Scaffold(
          body: Builder(
            builder: (inner) => ElevatedButton(
              onPressed: () => showCameraSnapshotSheet(
                inner,
                cameraId: 'cam-live',
                preview: preview,
                favorites: favs,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}
