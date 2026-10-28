// T07 / T06-D4: when the backend rejects the app's reader key (401/403),
// retrying is pointless — the catalog must surface a dedicated
// "update required" state instead of the generic error + retry button.
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_cubit.dart';
import 'package:flutter_starter/src/theme/theme.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import '../../support/camera_fakes.dart';

class FailingCameraRepository implements CameraRepository {
  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  FailingCameraRepository(this.statusCode);

  final int statusCode;

  Failure get _failure =>
      ApiFailure('HTTP $statusCode', statusCode: statusCode);

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      Left(_failure);

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      Left(_failure);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      Left(_failure);

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      Left(_failure);

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
          {String? etag, CancelToken? cancelToken}) async =>
      Left(_failure);
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
        'update_required_title': 'Cần cập nhật ứng dụng',
        'update_required_body':
            'Phiên bản này không còn được hỗ trợ. Vui lòng cài bản mới nhất để tiếp tục xem camera.',
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
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
    await AppConfig.init(
      config: const CameraConnectionConfig(
        baseUrl: 'http://localhost:3000',
        readerKey: 'test-key',
        demoMode: true,
      ),
    );
  });

  group('CameraCatalogState.isUpdateRequired', () {
    Future<CameraCatalogCubit> startedCubit(int statusCode) async {
      final cubit =
          CameraCatalogCubit(repository: FailingCameraRepository(statusCode));
      await cubit.start();
      return cubit;
    }

    test('is true when the catalog load fails with 401', () async {
      final cubit = await startedCubit(401);
      expect(cubit.state.isUpdateRequired, isTrue);
      await cubit.close();
    });

    test('is true when the catalog load fails with 403', () async {
      final cubit = await startedCubit(403);
      expect(cubit.state.isUpdateRequired, isTrue);
      await cubit.close();
    });

    test('is false for a 500 failure (generic error path)', () async {
      final cubit = await startedCubit(500);
      expect(cubit.state.isUpdateRequired, isFalse);
      await cubit.close();
    });

    test('is false for a 429 failure (backoff path, not update)', () async {
      final cubit = await startedCubit(429);
      expect(cubit.state.isUpdateRequired, isFalse);
      await cubit.close();
    });
  });

  group('CameraScreen update-required gate', () {
    Widget buildApp(int statusCode) {
      return EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const FakeAssetLoader(),
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: buildLightTheme(primaryColorHex: '#00897B'),
              home: CameraFeature(
                cameraRepository: FailingCameraRepository(statusCode),
                favoritesRepository: InMemoryFavoritesRepository(),
              ),
            );
          },
        ),
      );
    }

    Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('401 shows the update-required screen with no retry button',
        (tester) async {
      await tester.pumpWidget(buildApp(401));
      await pumpUntilFound(tester, find.text('Cần cập nhật ứng dụng'));
      expect(find.text('Cần cập nhật ứng dụng'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('500 keeps the generic error with a retry button',
        (tester) async {
      await tester.pumpWidget(buildApp(500));
      await pumpUntilFound(tester, find.text('Không thể tải danh sách camera'));
      expect(find.text('Không thể tải danh sách camera'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Cần cập nhật ứng dụng'), findsNothing);
    });
  });
}
