import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/preview_clock.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/utils/async_state.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class FakeTimer implements Timer {
  FakeTimer({required this.delay, required this.callback});
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

class FakePreviewClock implements PreviewClock {
  DateTime currentTime = DateTime.utc(2026, 10, 16, 12, 0, 0);
  final List<FakeTimer> scheduledTimers = [];

  @override
  DateTime now() => currentTime;

  @override
  Timer schedule(Duration delay, void Function() callback) {
    final timer = FakeTimer(delay: delay, callback: callback);
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

  FakeTimer? get latestTimer =>
      scheduledTimers.isNotEmpty ? scheduledTimers.last : null;
}

class ControlledCameraRepository implements CameraRepository {
  FutureEither<Camera> Function(String id, CancelToken? token)? onDetail;
  FutureEither<PlaybackDescriptor> Function(String id, CancelToken? token)?
      onPlayback;
  FutureEither<SnapshotReply> Function(
      String endpoint, String? etag, CancelToken? token)? onSnapshot;

  int snapshotCallCount = 0;
  final List<String?> sentEtags = [];

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async {
    if (onDetail != null) return onDetail!(id, cancelToken);
    return Right(Camera(
      id: id,
      name: 'Camera $id',
      provinceId: 'tp_hcm',
      district: 'Quan 1',
      snapshotCapable: true,
      snapshotEndpoint: '/api/v1/cameras/$id/snapshot',
      playbackEndpoint: '/api/v1/cameras/$id/playback',
    ));
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
      {CancelToken? cancelToken}) async {
    if (onPlayback != null) return onPlayback!(id, cancelToken);
    return Right(PlaybackDescriptor(
      cameraId: id,
      kind: 'snapshot',
      snapshotEndpoint: '/api/v1/cameras/$id/snapshot',
      refreshIntervalMs: 12000,
    ));
  }

  @override
  FutureEither<SnapshotReply> snapshot(
    String endpoint, {
    String? etag,
    CancelToken? cancelToken,
  }) async {
    snapshotCallCount++;
    sentEtags.add(etag);
    if (onSnapshot != null) return onSnapshot!(endpoint, etag, cancelToken);
    return Right(SnapshotReceived(SnapshotFrame(
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
      etag: 'etag-$snapshotCallCount',
      fetchedAt: DateTime.utc(2026, 10, 16, 12, 0, 0),
    )));
  }

  @override
  FutureEither<List<DistrictOption>> districts(
      {CancelToken? cancelToken}) async {
    return const Right([]);
  }

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    return const Right(CatalogPage(
      items: [],
      limit: 50,
      offset: 0,
      total: 0,
      catalogVersion: 'v1',
    ));
  }
}

void main() {
  group('CameraPreviewCubit Task 6 Polling, ETag, Lifecycle', () {
    late ControlledCameraRepository repository;
    late FakePreviewClock clock;
    late CameraPreviewCubit cubit;

    setUp(() {
      repository = ControlledCameraRepository();
      clock = FakePreviewClock();
      cubit = CameraPreviewCubit(
        repository: repository,
        clock: clock,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('one_request_in_flight', () async {
      final completer = Completer<Either<Failure, SnapshotReply>>();
      repository.onSnapshot = (endpoint, etag, token) => completer.future;

      // Start opening camera
      final future = cubit.open('cam-1');
      await Future<void>.delayed(Duration.zero);

      expect(repository.snapshotCallCount, equals(1));

      // Attempt another open or refresh while request 1 is still in flight
      // Calling retry() should not spawn concurrent snapshot request
      unawaited(cubit.retry());
      await Future<void>.delayed(Duration.zero);

      expect(repository.snapshotCallCount, equals(1));

      // Complete in-flight request
      completer.complete(Right(SnapshotReceived(SnapshotFrame(
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        etag: 'etag-1',
        fetchedAt: clock.now(),
      ))));
      await future;
    });

    test('late_A_never_replaces_B', () async {
      final completerA = Completer<Either<Failure, SnapshotReply>>();
      var callIndex = 0;

      repository.onSnapshot = (endpoint, etag, token) {
        callIndex++;
        if (callIndex == 1) {
          return completerA.future;
        } else {
          return Future.value(Right(SnapshotReceived(SnapshotFrame(
            bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), // B frame
            etag: 'etag-B',
            fetchedAt: clock.now(),
          ))));
        }
      };

      // Open camera A
      unawaited(cubit.open('cam-A'));
      await Future<void>.delayed(Duration.zero);

      // User quickly switches to camera B
      await cubit.open('cam-B');
      expect(cubit.state.cameraId, equals('cam-B'));
      expect(cubit.state.currentFrame?.etag, equals('etag-B'));

      // Late response for A arrives
      completerA.complete(Right(SnapshotReceived(SnapshotFrame(
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), // A frame
        etag: 'etag-A',
        fetchedAt: clock.now(),
      ))));
      await Future<void>.delayed(Duration.zero);

      // State MUST remain B, not overwritten by A
      expect(cubit.state.cameraId, equals('cam-B'));
      expect(cubit.state.currentFrame?.etag, equals('etag-B'));
    });

    test('304_keeps_frame_and_fetchedAt', () async {
      // First fetch: 200 with initial frame
      final initialTime = clock.now();
      final initialBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      repository.onSnapshot = (endpoint, etag, token) async {
        if (etag == null) {
          return Right(SnapshotReceived(SnapshotFrame(
            bytes: initialBytes,
            etag: 'etag-v1',
            fetchedAt: initialTime,
          )));
        } else {
          // Second fetch sends ETag and gets 304
          return const Right(SnapshotUnchanged());
        }
      };

      await cubit.open('cam-1');
      expect(cubit.state.currentFrame?.etag, equals('etag-v1'));
      expect(cubit.state.currentFrame?.bytes, equals(initialBytes));

      // Advance clock and trigger scheduled poll
      clock.advance(const Duration(seconds: 12));
      await Future<void>.delayed(Duration.zero);

      // Frame bytes kept, etag kept, fetchedAt preserved
      expect(cubit.state.currentFrame?.bytes, equals(initialBytes));
      expect(cubit.state.currentFrame?.etag, equals('etag-v1'));
      expect(cubit.state.currentFrame?.fetchedAt, equals(initialTime));
      expect(repository.sentEtags, contains('etag-v1'));
    });

    test('304_without_bytes_recovers_unconditionally_once', () async {
      var fetchCount = 0;
      // Simulate state where 304 received but cubit has no bytes
      repository.onSnapshot = (endpoint, etag, token) async {
        fetchCount++;
        if (fetchCount == 1) {
          // Unexpected 304 without bytes on first fetch
          return const Right(SnapshotUnchanged());
        } else {
          // Unconditional recovery fetch succeeds with bytes
          return Right(SnapshotReceived(SnapshotFrame(
            bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
            etag: 'etag-recovered',
            fetchedAt: clock.now(),
          )));
        }
      };

      await cubit.open('cam-1');
      expect(fetchCount, equals(2));
      expect(cubit.state.currentFrame?.etag, equals('etag-recovered'));
    });

    test('refresh_error_keeps_frame', () async {
      final initialBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      var fetchCount = 0;
      repository.onSnapshot = (endpoint, etag, token) async {
        fetchCount++;
        if (fetchCount == 1) {
          return Right(SnapshotReceived(SnapshotFrame(
            bytes: initialBytes,
            etag: 'etag-1',
            fetchedAt: clock.now(),
          )));
        } else {
          // Network error on refresh
          return const Left(
              ApiFailure('Lỗi mạng', statusCode: 503, retryable: true));
        }
      };

      await cubit.open('cam-1');
      expect(cubit.state.currentFrame?.bytes, equals(initialBytes));

      // Poll triggers error
      clock.advance(const Duration(seconds: 12));
      await Future<void>.delayed(Duration.zero);

      // Frame must be kept even though refresh failed
      expect(cubit.state.currentFrame?.bytes, equals(initialBytes));
      expect(cubit.state.snapshotState, isA<RequestFailure<SnapshotReply>>());
    });

    test('invalid_image_does_not_replace_good_frame', () async {
      final goodBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      var fetchCount = 0;
      repository.onSnapshot = (endpoint, etag, token) async {
        fetchCount++;
        if (fetchCount == 1) {
          return Right(SnapshotReceived(SnapshotFrame(
            bytes: goodBytes,
            etag: 'etag-good',
            fetchedAt: clock.now(),
          )));
        } else {
          // Repository or client returned invalid decode failure
          return const Left(ApiFailure('Ảnh không hợp lệ',
              statusCode: 422, retryable: false));
        }
      };

      await cubit.open('cam-1');
      expect(cubit.state.currentFrame?.bytes, equals(goodBytes));

      // Refresh poll
      clock.advance(const Duration(seconds: 12));
      await Future<void>.delayed(Duration.zero);

      // Frame is preserved
      expect(cubit.state.currentFrame?.bytes, equals(goodBytes));
    });

    test('dismiss_background_cancel_and_ignore_completion', () async {
      final completer = Completer<Either<Failure, SnapshotReply>>();
      repository.onSnapshot = (endpoint, etag, token) => completer.future;

      unawaited(cubit.open('cam-1'));
      await Future<void>.delayed(Duration.zero);

      // User dismisses sheet
      cubit.dismiss();
      expect(cubit.state.cameraId, isNull);

      // Request completes later
      completer.complete(Right(SnapshotReceived(SnapshotFrame(
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        etag: 'etag-late',
        fetchedAt: clock.now(),
      ))));
      await Future<void>.delayed(Duration.zero);

      // State remains dismissed
      expect(cubit.state.cameraId, isNull);
      expect(cubit.state.currentFrame, isNull);
    });

    test('resume_has_single_chain', () async {
      await cubit.open('cam-1');
      final callsBefore = repository.snapshotCallCount;

      // Background app
      cubit.setForeground(false);
      clock.advance(const Duration(seconds: 30));
      // No polling when backgrounded
      expect(repository.snapshotCallCount, equals(callsBefore));

      // Resume app
      cubit.setForeground(true);
      await Future<void>.delayed(Duration.zero);

      // Immediate refresh triggered once
      expect(repository.snapshotCallCount, equals(callsBefore + 1));
    });

    test('viewer_rotation_detents_do_not_duplicate_polling', () async {
      await cubit.open('cam-1');
      final initialCount = repository.snapshotCallCount;

      // Viewer open / rotate does not trigger duplicate chains
      cubit.notifyViewerOrientationChange();
      await Future<void>.delayed(Duration.zero);

      expect(repository.snapshotCallCount, equals(initialCount));
    });

    test('retry_policy_respects_status_and_retry_after', () async {
      // 429 Too Many Requests with Retry-After: 90
      repository.onSnapshot = (endpoint, etag, token) async {
        return const Left(ApiFailure(
          'Quá nhiều yêu cầu',
          statusCode: 429,
          retryable: true,
          retryAfter: Duration(seconds: 90),
        ));
      };

      await cubit.open('cam-1');

      // Scheduled timer should be 90s (max(60s, 90s))
      expect(clock.latestTimer?.delay, equals(const Duration(seconds: 90)));

      // 401 Unauthorized stops polling
      repository.onSnapshot = (endpoint, etag, token) async {
        return const Left(ApiFailure(
          'Không có quyền truy cập',
          statusCode: 401,
          retryable: false,
        ));
      };

      await cubit.open('cam-1');
      // No active timer scheduled on 401
      expect(clock.latestTimer?.isActive, isFalse);
    });
  });
}
