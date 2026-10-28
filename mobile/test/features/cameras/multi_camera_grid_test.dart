import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/multi_camera_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_favorites_section.dart';
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

FavoriteCamera fav(String id, {bool missing = false}) => FavoriteCamera(
      id: id,
      name: 'Cam $id',
      addedAt: DateTime(2026, 10, 20),
      isMissingFromCatalog: missing,
    );

class _Repo implements CameraRepository {
  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      const Right(CatalogPage(
        items: [],
        limit: 50,
        offset: 0,
        total: 0,
        catalogVersion: 'v1',
        dataMode: 'fixture',
      ));

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      Right(Camera(
        id: id,
        name: 'Cam $id',
        provinceId: 'tp_hcm',
        snapshotCapable: true,
        playbackEndpoint: '/v1/cameras/$id/playback',
        snapshotEndpoint: '/v1/cameras/$id/snapshot',
      ));

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
        'camera': {
          'favorites_title': 'Quan tâm',
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
        'shared': {'retry': 'Thử lại'},
      };
}

Widget _wrap(Widget child) {
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

  group('selectGridFavorites', () {
    test('caps at 6 and preserves order', () {
      final result = selectGridFavorites([
        for (var i = 1; i <= 8; i++) fav('c$i'),
      ]);
      expect(result.map((f) => f.id), ['c1', 'c2', 'c3', 'c4', 'c5', 'c6']);
    });

    test('skips favorites missing from the catalog', () {
      final result = selectGridFavorites([
        fav('c1'),
        fav('gone', missing: true),
        fav('c2'),
      ]);
      expect(result.map((f) => f.id), ['c1', 'c2']);
    });

    test('respects a custom max', () {
      final result =
          selectGridFavorites([fav('c1'), fav('c2'), fav('c3')], max: 2);
      expect(result, hasLength(2));
    });
  });

  group('MultiCameraScreen', () {
    testWidgets('renders a cell per selected favorite with its name',
        (tester) async {
      await tester.pumpWidget(_wrap(MultiCameraScreen(
        favorites: [fav('c1'), fav('c2'), fav('c3')],
        repository: _Repo(),
        favoritesRepository: _Favs(),
        refreshInterval: const Duration(minutes: 5),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('grid_cell_c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid_cell_c2')), findsOneWidget);
      expect(find.byKey(const ValueKey('grid_cell_c3')), findsOneWidget);
      expect(find.text('Cam c2'), findsOneWidget);
      // Unmount to cancel the refresh timer before the test ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('empty selection shows the empty message', (tester) async {
      await tester.pumpWidget(_wrap(MultiCameraScreen(
        favorites: [fav('gone', missing: true)],
        repository: _Repo(),
        favoritesRepository: _Favs(),
        refreshInterval: const Duration(minutes: 5),
      )));
      await tester.pump();
      expect(find.text('Chưa có camera Quan tâm khả dụng'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('CameraFavoritesSection grid entry', () {
    testWidgets('grid button hidden below 2 favorites, shown at 2',
        (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: CameraFavoritesSection(
          favorites: [fav('c1')],
          onViewGrid: () {},
        ),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('view_grid_button')), findsNothing);

      await tester.pumpWidget(_wrap(Scaffold(
        body: CameraFavoritesSection(
          favorites: [fav('c1'), fav('c2')],
          onViewGrid: () {},
        ),
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('view_grid_button')), findsOneWidget);
    });
  });
}
