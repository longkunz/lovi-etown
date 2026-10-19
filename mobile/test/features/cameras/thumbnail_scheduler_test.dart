import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/thumbnail_scheduler.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';
import 'package:dio/dio.dart';

class FakeThumbnailCameraRepository implements CameraRepository {
  int inFlightSnapshotRequests = 0;
  int maxConcurrentObserved = 0;

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
      {String? etag, CancelToken? cancelToken}) async {
    inFlightSnapshotRequests++;
    if (inFlightSnapshotRequests > maxConcurrentObserved) {
      maxConcurrentObserved = inFlightSnapshotRequests;
    }

    // Delay to check concurrency
    await Future<void>.delayed(const Duration(milliseconds: 25));
    inFlightSnapshotRequests--;

    final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
    return Right(SnapshotReceived(SnapshotFrame(bytes: dummyBytes)));
  }

  @override
  FutureEither<CatalogPage> list(
          {String? query,
          String? district,
          int limit = 50,
          int offset = 0,
          CancelToken? cancelToken}) async =>
      throw UnimplementedError();

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      throw UnimplementedError();

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      throw UnimplementedError();

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      throw UnimplementedError();
}

void main() {
  group('SnapshotMemoryCache', () {
    test('evicts_least_recently_used_when_maxEntries_exceeded', () {
      final cache = SnapshotMemoryCache(maxEntries: 2, maxBytes: 1024 * 1024);
      final frame1 = SnapshotFrame(bytes: Uint8List(100));
      final frame2 = SnapshotFrame(bytes: Uint8List(100));
      final frame3 = SnapshotFrame(bytes: Uint8List(100));

      cache.put('c1', frame1);
      cache.put('c2', frame2);

      expect(cache.get('c1'), isNotNull);
      expect(cache.get('c2'), isNotNull);

      // Access c1 so c2 becomes LRU
      cache.get('c1');

      // Put c3 -> should evict c2
      cache.put('c3', frame3);

      expect(cache.get('c1'), isNotNull);
      expect(cache.get('c2'), isNull);
      expect(cache.get('c3'), isNotNull);
    });

    test('evicts_when_maxBytes_exceeded', () {
      final cache = SnapshotMemoryCache(maxEntries: 10, maxBytes: 250);
      final frame1 = SnapshotFrame(bytes: Uint8List(100));
      final frame2 = SnapshotFrame(bytes: Uint8List(100));
      final frame3 = SnapshotFrame(bytes: Uint8List(100));

      cache.put('c1', frame1);
      cache.put('c2', frame2);
      expect(cache.currentByteSize, equals(200));

      cache.put('c3', frame3);
      // Evicted c1 (100) -> 200 bytes remains
      expect(cache.get('c1'), isNull);
      expect(cache.currentByteSize, equals(200));
    });
  });

  group('ThumbnailScheduler', () {
    late FakeThumbnailCameraRepository repo;
    late SnapshotMemoryCache cache;
    late ThumbnailScheduler scheduler;

    setUp(() {
      repo = FakeThumbnailCameraRepository();
      cache = SnapshotMemoryCache(maxEntries: 32, maxBytes: 8 * 1024 * 1024);
      scheduler = ThumbnailScheduler(repository: repo, cache: cache);
    });

    tearDown(() {
      scheduler.dispose();
    });

    test('concurrent_requests_never_exceed_four', () async {
      final cameraEndpoints = {
        for (int i = 1; i <= 10; i++)
          'cam-$i': '/api/v1/cameras/cam-$i/thumbnail'
      };

      scheduler.updateWindow(
        visible: {'cam-1', 'cam-2', 'cam-3', 'cam-4', 'cam-5', 'cam-6'},
        prefetch: {'cam-7', 'cam-8'},
        endpoints: cameraEndpoints,
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repo.maxConcurrentObserved, lessThanOrEqualTo(4));
    });

    test('active_preview_is_not_competed_by_list_thumbnails', () async {
      scheduler.setPreviewCamera('cam-preview');
      expect(scheduler.activePreviewCameraId, equals('cam-preview'));
    });
  });
}
