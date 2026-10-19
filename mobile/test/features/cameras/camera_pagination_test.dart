import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:dio/dio.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_cubit.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class FakePagingRepository implements CameraRepository {
  int listCalls = 0;
  String currentVersion = 'v1';
  bool failNextPage = false;

  CatalogPage makePage(
      {required int offset,
      required int limit,
      required int count,
      required int total}) {
    return CatalogPage(
      items: List.generate(
        count,
        (i) => Camera(
          id: 'cam-${offset + i}',
          name: 'Camera ${offset + i}',
          provinceId: 'tp_hcm',
          playbackEndpoint: '/playback',
        ),
      ),
      limit: limit,
      offset: offset,
      total: total,
      catalogVersion: currentVersion,
      isStale: false,
      dataMode: 'real',
    );
  }

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    listCalls++;
    if (offset > 0 && failNextPage) {
      return const Left(NetworkFailure('Paging connection failed'));
    }
    return Right(
        makePage(offset: offset, limit: limit, count: limit, total: 200));
  }

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      throw UnimplementedError();

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      throw UnimplementedError();

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
          {String? etag, CancelToken? cancelToken}) async =>
      throw UnimplementedError();
}

void main() {
  group('CameraPagination', () {
    late FakePagingRepository repo;
    late CameraCatalogCubit cubit;

    setUp(() {
      repo = FakePagingRepository();
      cubit = CameraCatalogCubit(repository: repo);
    });

    tearDown(() {
      cubit.close();
    });

    test('loadNextPage_appends_items_and_updates_offset', () async {
      await cubit.start();
      expect(cubit.state.items.length, equals(50));
      expect(cubit.state.nextOffset, equals(50));
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadNextPage();
      expect(cubit.state.items.length, equals(100));
      expect(cubit.state.nextOffset, equals(100));
    });

    test('paging_error_keeps_existing_items_and_sets_failure_state', () async {
      await cubit.start();
      expect(cubit.state.items.length, equals(50));

      repo.failNextPage = true;
      await cubit.loadNextPage();

      // Items are NOT wiped on next page failure!
      expect(cubit.state.items.length, equals(50));
      expect(cubit.state.paginationState.isFailure, isTrue);
    });

    test('offset_capped_at_10000', () async {
      await cubit.start();

      // Emit state with nextOffset at 10000
      cubit.emit(cubit.state.copyWith(nextOffset: 10000, hasMore: true));
      final initialCalls = repo.listCalls;

      await cubit.loadNextPage();
      expect(repo.listCalls, equals(initialCalls));
    });
  });
}
