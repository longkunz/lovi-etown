import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_screen.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InsetCameraRepository implements CameraRepository {
  final cameras = [
    const Camera(
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Nguyen Hue - Le Loi',
      provinceId: 'tp_hcm',
      district: 'Quan 1',
      playbackEndpoint: '/playback/1',
    ),
  ];

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      Right(CatalogPage(
        items: cameras,
        limit: limit,
        offset: offset,
        total: cameras.length,
        catalogVersion: 'v1',
        isStale: false,
        dataMode: 'fixture',
      ));

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<Camera> detail(String id,
          {CancelToken? cancelToken}) async =>
      Right(cameras.first);

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      throw UnimplementedError();

  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<SnapshotReply> snapshot(
    String endpoint, {
    String? etag,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();
}

class _InsetFavoritesRepository implements FavoritesRepository {
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

class _InsetAssetLoader extends AssetLoader {
  const _InsetAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'shared': {
        'retry': 'Thử lại',
        'close': 'Đóng',
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

  // Inset contract (#56): the shell (CameraNavigationShell) adds no
  // SafeArea, so the camera tab owns its top inset exactly once. With
  // extendBodyBehindAppBar, Scaffold bumps the body's MediaQuery
  // padding.top up to the full AppBar height (status bar + toolbar), so
  // the spacer must be exactly that padding — adding kToolbarHeight again
  // double-counts 56px (the old formula did exactly that: with a 32px
  // status bar the spacer was 144px while the AppBar occupies 88px).
  // If someone wraps this body in a SafeArea later, content double-pads
  // and the glass header gains a gap above it; if the spacer shrinks,
  // the filters slide under the header.
  testWidgets('camera tab owns exactly one top inset, no SafeArea doubling',
      (tester) async {
    const statusBarHeight = 32.0;
    final repo = _InsetCameraRepository();
    final cubit = CameraCatalogCubit(repository: repo);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const _InsetAssetLoader(),
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: statusBarHeight),
              ),
              child: CameraScreen(
                catalogCubit: cubit,
                favoritesRepository: _InsetFavoritesRepository(),
                cameraRepository: repo,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The body must extend behind the transparent glass AppBar, otherwise
    // the spacer below would be redundant padding.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.extendBodyBehindAppBar, isTrue);

    // Exactly one spacer: the body's padding.top, which Scaffold bumped
    // to status-bar height + toolbar height (88px here). The old formula
    // (padding.top + kToolbarHeight) produced 144px here and fails this.
    final spacer = find.byWidgetPredicate((widget) =>
        widget is SizedBox &&
        widget.height == statusBarHeight + kToolbarHeight);
    expect(spacer, findsOneWidget);

    // The spacer starts at the very top of the body (y = 0): no SafeArea
    // or extra padding sits above the scroll content. (The AppBar brings
    // its own structural SafeArea for the toolbar, but that wraps the
    // AppBar, not this body, so it cannot double-pad the tab.)
    expect(tester.getTopLeft(spacer).dy, 0.0);
  });
}
