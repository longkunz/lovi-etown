import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_tile.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_filters.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';
import 'package:dio/dio.dart';

class FakeScreenCameraRepository implements CameraRepository {
  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  final List<Camera> cameras = [
    const Camera(
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Nguyen Hue - Le Loi',
      provinceId: 'tp_hcm',
      district: 'Quan 1',
      address: 'Ben Nghe, Quan 1',
      snapshotCapable: true,
      playbackEndpoint: '/playback/1',
      thumbnailEndpoint: '/thumbnail/1',
    ),
    const Camera(
      id: '00000000-0000-0000-0000-000000000002',
      name: 'Cong Hoa - Hoang Hoa Tham',
      provinceId: 'tp_hcm',
      district: 'Tan Binh',
      snapshotCapable: true,
      playbackEndpoint: '/playback/2',
      thumbnailEndpoint: '/thumbnail/2',
    ),
  ];

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    return Right(CatalogPage(
      items: cameras,
      limit: limit,
      offset: offset,
      total: cameras.length,
      catalogVersion: 'v1',
      isStale: false,
      dataMode: 'fixture',
    ));
  }

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async {
    return const Right([
      DistrictOption(name: 'Quan 1', count: 1),
      DistrictOption(name: 'Tan Binh', count: 1),
    ]);
  }

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async {
    return Right(cameras.firstWhere((c) => c.id == id));
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint, {String? etag, CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }
}

class FakeFavoritesRepository implements FavoritesRepository {
  final List<FavoriteCamera> _favorites = [];

  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield List.unmodifiable(_favorites);
  }

  @override
  FutureEither<void> load() async => const Right(null);

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async {
    if (saved) {
      _favorites.add(FavoriteCamera(
        id: camera.id,
        name: camera.name,
        district: camera.district,
        address: camera.address,
        addedAt: DateTime.now(),
      ));
    } else {
      _favorites.removeWhere((f) => f.id == camera.id);
    }
    return const Right(null);
  }

  @override
  FutureEither<void> resetCorruptData() async => const Right(null);
}

class FakeAssetLoader extends AssetLoader {
  const FakeAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'shared': {
        'retry': 'Thử lại',
        'close': 'Đóng',
        'demo_mode_badge': 'Dữ liệu mẫu',
      },
      'camera': {
        'title': 'Camera giao thông',
        'search_hint': 'Tìm tên đường, giao lộ...',
        'all_districts': 'Tất cả quận/huyện',
        'favorites_title': 'Quan tâm',
        'empty_favorites': 'Chưa có camera quan tâm',
        'view_card': 'Thẻ',
        'view_grid': 'Lưới',
        'view_list': 'Danh sách',
      },
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('ready_screen_shows_thumbnail_and_inline_favorites', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = FakeScreenCameraRepository();
    final favRepo = FakeFavoritesRepository();
    final cubit = CameraCatalogCubit(repository: repo);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const FakeAssetLoader(),
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: CameraScreen(
              catalogCubit: cubit,
              favoritesRepository: favRepo,
              cameraRepository: repo,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CameraFilters), findsOneWidget);
    expect(find.text('Quan tâm'), findsOneWidget);
    expect(find.byType(CameraTile), findsWidgets);
    expect(find.text('Nguyen Hue - Le Loi'), findsOneWidget);
  });
}
