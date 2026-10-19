import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_cubit.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class FakeCameraRepository implements CameraRepository {
  Completer<CatalogPage>? nextListCompleter;
  int listCallCount = 0;
  String? lastQuery;
  String? lastDistrict;

  List<DistrictOption> districtOptions = const [
    DistrictOption(name: 'Quận 1', count: 12),
    DistrictOption(name: 'Quận 3', count: 8),
  ];

  CatalogPage samplePage({int offset = 0, int limit = 50, int total = 100, List<Camera>? items}) {
    return CatalogPage(
      items: items ?? [
        const Camera(
          id: '00000000-0000-0000-0000-000000000001',
          name: 'Nguyễn Huệ - Lê Lợi',
          provinceId: 'tp_hcm',
          district: 'Quận 1',
          address: 'Bến Nghé, Quận 1',
          snapshotCapable: true,
          thumbnailEndpoint: '/api/v1/cameras/00000000-0000-0000-0000-000000000001/thumbnail',
          snapshotEndpoint: '/api/v1/cameras/00000000-0000-0000-0000-000000000001/snapshot',
          playbackEndpoint: '/api/v1/cameras/00000000-0000-0000-0000-000000000001/playback',
        ),
      ],
      limit: limit,
      offset: offset,
      total: total,
      catalogVersion: 'v1',
      isStale: false,
      dataMode: 'fixture',
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
    listCallCount++;
    lastQuery = query;
    lastDistrict = district;
    if (nextListCompleter != null) {
      final res = await nextListCompleter!.future;
      return Right(res);
    }
    return Right(samplePage(offset: offset, limit: limit));
  }

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async {
    return Right(districtOptions);
  }

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async {
    throw UnimplementedError();
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

void main() {
  group('CameraCatalogCubit', () {
    late FakeCameraRepository repo;
    late CameraCatalogCubit cubit;

    setUp(() {
      repo = FakeCameraRepository();
      cubit = CameraCatalogCubit(repository: repo);
    });

    tearDown(() {
      cubit.close();
    });

    test('one_character_query_skips_request', () async {
      await cubit.start();
      final initialCalls = repo.listCallCount;

      cubit.setQuery('a');
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(repo.listCallCount, equals(initialCalls));
      expect(cubit.state.queryValidationMessage, isNotNull);
    });

    test('dropdown_uses_repository_labels', () async {
      await cubit.start();
      expect(cubit.state.districts.length, equals(2));
      expect(cubit.state.districts.first.name, equals('Quận 1'));
    });

    test('mode_change_keeps_filters_and_camera_anchor', () async {
      await cubit.start();
      cubit.setDistrict('Quận 1');
      cubit.setAnchorCameraId('00000000-0000-0000-0000-000000000001');

      cubit.setViewMode(CameraViewMode.grid);
      cubit.setGridDensity(GridDensity.compact);

      expect(cubit.state.district, equals('Quận 1'));
      expect(cubit.state.viewMode, equals(CameraViewMode.grid));
      expect(cubit.state.gridDensity, equals(GridDensity.compact));
      expect(cubit.state.anchorCameraId, equals('00000000-0000-0000-0000-000000000001'));
    });

    test('stale_query_response_is_discarded', () async {
      await cubit.start();

      // Trigger first query A with a pending completer
      final completerA = Completer<CatalogPage>();
      repo.nextListCompleter = completerA;

      cubit.setQuery('Hai Ba Trung');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final generationA = cubit.state.generation;

      // Trigger second query B
      final completerB = Completer<CatalogPage>();
      repo.nextListCompleter = completerB;
      cubit.setQuery('Nguyen Hue');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final generationB = cubit.state.generation;

      expect(generationB, greaterThan(generationA));

      // Resolve B first
      completerB.complete(repo.samplePage(items: [
        const Camera(
          id: '00000000-0000-0000-0000-000000000002',
          name: 'Nguyen Hue',
          provinceId: 'tp_hcm',
          snapshotCapable: true,
          playbackEndpoint: '/playback',
        ),
      ]));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.items.first.name, equals('Nguyen Hue'));

      // Late response from A arrives
      completerA.complete(repo.samplePage(items: [
        const Camera(
          id: '00000000-0000-0000-0000-000000000001',
          name: 'Hai Ba Trung',
          provinceId: 'tp_hcm',
          snapshotCapable: true,
          playbackEndpoint: '/playback',
        ),
      ]));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Items should STILL be from query B!
      expect(cubit.state.items.first.name, equals('Nguyen Hue'));
    });

    test('consecutive_pages_deduplicate_items_by_id', () async {
      await cubit.start();
      expect(cubit.state.items.length, 1);

      // Page 2 has the same camera plus a new camera
      const cam1 = Camera(
        id: '00000000-0000-0000-0000-000000000001',
        name: 'Cam 1',
        provinceId: 'tp_hcm',
        playbackEndpoint: '/playback/1',
      );
      const cam2 = Camera(
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Cam 2',
        provinceId: 'tp_hcm',
        playbackEndpoint: '/playback/2',
      );

      const page2 = CatalogPage(
        items: [cam1, cam2],
        limit: 50,
        offset: 50,
        total: 100,
        catalogVersion: 'v1',
      );

      repo.nextListCompleter = Completer<CatalogPage>()..complete(page2);
      await cubit.loadNextPage();

      expect(cubit.state.items.length, 2);
      expect(cubit.state.items.map((c) => c.id).toList(), [
        '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000002',
      ]);
    });

    test('catalog_version_mismatch_restarts_from_page_0', () async {
      await cubit.start();
      expect(cubit.state.catalogVersion, 'v1');

      // Page 2 arrives with catalogVersion 'v2'
      const page2 = CatalogPage(
        items: [
          Camera(
            id: '00000000-0000-0000-0000-000000000002',
            name: 'Cam 2',
            provinceId: 'tp_hcm',
            playbackEndpoint: '/playback/2',
          ),
        ],
        limit: 50,
        offset: 50,
        total: 100,
        catalogVersion: 'v2',
      );

      // Set up nextListCompleter for page 2, then for the reset page 0
      repo.nextListCompleter = Completer<CatalogPage>()..complete(page2);
      await cubit.loadNextPage();

      // Because catalogVersion changed to 'v2', it reloaded page 0
      expect(repo.listCallCount, 3); // initial (1) + page 2 (2) + reload page 0 (3)
    });
  });
}
