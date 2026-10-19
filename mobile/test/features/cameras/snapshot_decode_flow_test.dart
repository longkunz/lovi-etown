import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/api_camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/thumbnail_scheduler.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/preview_clock.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/services/camera_api_client.dart';
import 'package:flutter_starter/src/utils/async_state.dart';

class _FakeTimer implements Timer {
  _FakeTimer({required this.delay, required this.callback});
  final Duration delay;
  final void Function() callback;
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 1;

  @override
  void cancel() {
    _isActive = false;
  }

  void fire() {
    if (_isActive) {
      _isActive = false;
      callback();
    }
  }
}

class _FakePreviewClock implements PreviewClock {
  DateTime currentTime = DateTime.utc(2026, 10, 19, 12, 0, 0);
  final List<_FakeTimer> scheduledTimers = [];

  @override
  DateTime now() => currentTime;

  @override
  Timer schedule(Duration delay, void Function() callback) {
    final timer = _FakeTimer(delay: delay, callback: callback);
    scheduledTimers.add(timer);
    return timer;
  }

  void advance(Duration duration) {
    currentTime = currentTime.add(duration);
    final active = scheduledTimers.where((t) => t.isActive).toList();
    for (final timer in active) {
      timer.fire();
    }
  }
}

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter({required this.snapshotBytes});

  /// What the snapshot endpoint currently returns; tests swap this between
  /// a valid frame and an undecodable payload.
  Uint8List snapshotBytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/playback')) {
      return ResponseBody.fromString(
        '{"cameraId":"cam-1","kind":"snapshot","snapshotEndpoint":"/v1/cameras/cam-1/snapshot","refreshIntervalMs":12000}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (path.endsWith('/snapshot')) {
      return ResponseBody(
        Stream.value(snapshotBytes),
        200,
        headers: {
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    }
    // Camera detail
    return ResponseBody.fromString(
      '{"id":"cam-1","name":"Camera 1","provinceId":"tp_hcm","district":"Quan 1","capabilities":{"snapshot":true},"snapshotEndpoint":"/v1/cameras/cam-1/snapshot","playbackEndpoint":"/v1/cameras/cam-1/playback"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// SOI + APP0/JFIF header, then EOI immediately: passes magic-byte header
/// checks but has no decodable frame (T01 reproduction payload).
Uint8List _corruptJpeg() {
  final bytes = Uint8List(256);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  bytes[3] = 0xE0;
  bytes[4] = 0x00;
  bytes[5] = 0x10;
  bytes.setRange(6, 11, [0x4A, 0x46, 0x49, 0x46, 0x00]);
  bytes[20] = 0xFF;
  bytes[21] = 0xD9;
  return bytes;
}

void main() {
  group('Snapshot decode flow T01 (client -> repository -> preview/cache)',
      () {
    late Dio dio;
    late _RoutingAdapter adapter;
    late ApiCameraRepository repository;
    late Uint8List validJpeg;

    setUp(() async {
      validJpeg =
          await File('assets/fixtures/snapshots/sample1.jpg').readAsBytes();
      dio = Dio();
      adapter = _RoutingAdapter(snapshotBytes: validJpeg);
      dio.httpClientAdapter = adapter;
      final client = CameraApiClient(
        dio: dio,
        config: const CameraConnectionConfig(
          baseUrl: 'https://api.example.test',
          readerKey: 'reader-key',
        ),
      );
      repository = ApiCameraRepository(apiClient: client);
    });

    Future<void> flush() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
        'undecodable_refresh_keeps_last_good_frame_in_preview_and_shared_cache',
        () async {
      final clock = _FakePreviewClock();
      final cache = SnapshotMemoryCache();
      final cubit = CameraPreviewCubit(
        repository: repository,
        clock: clock,
        cache: cache,
      );

      await cubit.open('cam-1');
      expect(cubit.state.currentFrame?.bytes, equals(validJpeg));
      expect(cache.get('cam-1')?.bytes, equals(validJpeg));

      // The server now returns a payload with a valid JPEG header that
      // cannot be decoded.
      adapter.snapshotBytes = _corruptJpeg();
      clock.advance(const Duration(seconds: 12));
      await flush();

      // The last good frame survives in both the preview state and the
      // shared cache, and the refresh failure is visible in the state.
      expect(cubit.state.currentFrame?.bytes, equals(validJpeg));
      expect(cache.get('cam-1')?.bytes, equals(validJpeg));
      expect(
          cubit.state.snapshotState, isA<RequestFailure<SnapshotReply>>());
      expect(cubit.state.isStale, isTrue);

      await cubit.close();
    });

    test('undecodable_thumbnail_never_enters_shared_cache', () async {
      final cache = SnapshotMemoryCache();
      final scheduler = ThumbnailScheduler(
        repository: repository,
        cache: cache,
      );

      adapter.snapshotBytes = _corruptJpeg();
      scheduler.updateWindow(
        visible: {'cam-1'},
        prefetch: const {},
        endpoints: {'cam-1': '/v1/cameras/cam-1/snapshot'},
      );
      // Real waits: image decoding happens off the microtask queue.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await flush();
      expect(cache.get('cam-1'), isNull);

      // A valid payload for the same camera does enter the cache.
      adapter.snapshotBytes = validJpeg;
      scheduler.updateWindow(
        visible: {'cam-1'},
        prefetch: const {},
        endpoints: {'cam-1': '/v1/cameras/cam-1/snapshot'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await flush();
      expect(cache.get('cam-1')?.bytes, equals(validJpeg));

      scheduler.dispose();
    });
  });
}
