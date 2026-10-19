import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/preview_clock.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_state.dart';
import 'package:flutter_starter/src/utils/async_state.dart';
import 'package:flutter_starter/src/utils/failure.dart';

class CameraPreviewCubit extends Cubit<CameraPreviewState> {
  CameraPreviewCubit({
    required CameraRepository repository,
    PreviewClock clock = const SystemPreviewClock(),
    SnapshotMemoryCache? cache,
  })  : _repository = repository,
        _clock = clock,
        _cache = cache,
        super(const CameraPreviewState());

  final CameraRepository _repository;
  final PreviewClock _clock;
  final SnapshotMemoryCache? _cache;

  CancelToken? _cancelToken;
  Timer? _pollingTimer;
  int _generation = 0;
  bool _isInFlight = false;
  int _retryAttempt = 0;

  static const List<int> _backoffIntervals = [12, 24, 48, 60];

  Future<void> open(String id) async {
    _cancelToken?.cancel('New camera selected');
    _cancelToken = CancelToken();
    _pollingTimer?.cancel();

    _generation++;
    final currentGen = _generation;
    _isInFlight = false;
    _retryAttempt = 0;

    final isSameCamera = state.cameraId == id;
    final cachedFrame = _cache?.get(id);

    emit(state.copyWith(
      cameraId: id,
      camera: isSameCamera ? state.camera : null,
      clearCamera: !isSameCamera,
      descriptor: isSameCamera ? state.descriptor : null,
      clearDescriptor: !isSameCamera,
      cameraState: const RequestLoading(),
      snapshotState: const RequestLoading(),
      currentFrame: isSameCamera ? state.currentFrame : cachedFrame,
      clearCurrentFrame: !isSameCamera && cachedFrame == null,
      isStale: false,
    ));

    await _loadDetail(currentGen);
  }

  /// Stage 1 of loading a preview: fetch the camera detail, then continue
  /// to the descriptor stage. A retryable failure re-runs this stage, so the
  /// recovery chain never gets stuck fetching a snapshot before any
  /// endpoint exists (T02).
  Future<void> _loadDetail(int currentGen) async {
    final id = state.cameraId;
    if (id == null || _generation != currentGen) return;

    final detailResult =
        await _repository.detail(id, cancelToken: _cancelToken);
    if (_generation != currentGen) return;

    await detailResult.fold(
      (failure) async {
        emit(state.copyWith(
          cameraState: RequestFailure(failure),
          snapshotState: RequestFailure(failure),
        ));
        _handleFailure(
          failure,
          currentGen,
          onRetry: () => _loadDetail(currentGen),
        );
      },
      (camera) async {
        // This stage succeeded: the next stage starts its backoff from the
        // first interval instead of inheriting this stage's attempts.
        _retryAttempt = 0;
        emit(state.copyWith(
          camera: camera,
          cameraState: RequestSuccess(camera),
        ));
        await _loadDescriptor(currentGen);
      },
    );
  }

  /// Stage 2: fetch the playback descriptor, then the snapshot. When the
  /// descriptor fails but the camera itself carries a snapshot/thumbnail
  /// endpoint, the snapshot is still attempted through that endpoint. When
  /// no endpoint exists at all, the failure is surfaced on the snapshot
  /// state and a retryable failure re-runs this stage (T02).
  Future<void> _loadDescriptor(int currentGen) async {
    final id = state.cameraId;
    if (id == null || _generation != currentGen) return;

    final playbackResult =
        await _repository.playback(id, cancelToken: _cancelToken);
    if (_generation != currentGen) return;

    await playbackResult.fold(
      (failure) async {
        if (_cameraEndpoint() != null) {
          await _fetchSnapshot(currentGen);
          return;
        }
        emit(state.copyWith(
          snapshotState: RequestFailure(failure),
        ));
        _handleFailure(
          failure,
          currentGen,
          onRetry: () => _loadDescriptor(currentGen),
        );
      },
      (descriptor) async {
        _retryAttempt = 0;
        emit(state.copyWith(descriptor: descriptor));
        await _fetchSnapshot(currentGen);
      },
    );
  }

  String? _cameraEndpoint() {
    final camera = state.camera;
    if (camera == null || camera.id != state.cameraId) return null;
    final endpoint = camera.snapshotEndpoint ?? camera.thumbnailEndpoint;
    return (endpoint == null || endpoint.isEmpty) ? null : endpoint;
  }

  String _currentSnapshotEndpoint() {
    final descriptor = state.descriptor;
    if (descriptor != null &&
        descriptor.cameraId == state.cameraId &&
        descriptor.snapshotEndpoint.isNotEmpty) {
      return descriptor.snapshotEndpoint;
    }
    return _cameraEndpoint() ?? '';
  }

  Future<void> _fetchSnapshot(int currentGen,
      {bool forceWithoutEtag = false}) async {
    if (_generation != currentGen || !state.isForeground) return;
    if (_isInFlight) return;

    _isInFlight = true;

    final endpoint = _currentSnapshotEndpoint();

    if (endpoint.isEmpty) {
      _isInFlight = false;
      // No way to fetch an image at all: surface a terminal failure instead
      // of leaving the preview in a loading state forever (T02). There is
      // no automatic retry for this state; recovery goes through retry() /
      // foreground resume, which redo the descriptor stage that supplies
      // the endpoint.
      const failure = ApiFailure(
        'Camera không cung cấp địa chỉ ảnh xem trước',
        statusCode: 422,
      );
      emit(state.copyWith(
        snapshotState: const RequestFailure(failure),
        isStale: state.currentFrame != null,
      ));
      return;
    }

    final etagToSend = (forceWithoutEtag || state.currentFrame == null)
        ? null
        : state.currentFrame!.etag;

    _cancelToken ??= CancelToken();
    final snapResult = await _repository.snapshot(
      endpoint,
      etag: etagToSend,
      cancelToken: _cancelToken,
    );

    _isInFlight = false;
    if (_generation != currentGen) return;

    if (snapResult.isLeft()) {
      final failure = snapResult.fold((f) => f, (_) => throw Exception());
      if (failure is CancelledFailure || (_cancelToken?.isCancelled ?? false)) {
        return;
      }

      // A failed refresh is recognisable immediately: the frame on screen
      // is no longer confirmed current, so it is marked stale right away
      // instead of only after the 60-second age threshold (T02). The good
      // frame itself is always kept.
      emit(state.copyWith(
        snapshotState: RequestFailure(failure),
        isStale: state.currentFrame != null,
      ));

      _handleFailure(
        failure,
        currentGen,
        // While the descriptor is still missing, the retry redoes that
        // stage (which then continues to the snapshot); otherwise it
        // retries the snapshot directly.
        onRetry: () async {
          if (state.descriptor == null) {
            await _loadDescriptor(currentGen);
          } else {
            await _fetchSnapshot(currentGen);
          }
        },
      );
      return;
    }

    final reply = snapResult.fold((_) => throw Exception(), (r) => r);
    _retryAttempt = 0;

    switch (reply) {
      case SnapshotReceived(:final frame):
        _cache?.put(state.cameraId ?? '', frame);
        emit(state.copyWith(
          currentFrame: frame,
          snapshotState: RequestSuccess(reply),
          isStale: false,
        ));
        _scheduleNextPoll(currentGen);

      case SnapshotUnchanged():
        if (state.currentFrame == null) {
          // 304 without bytes edge case: recover unconditionally once
          if (!forceWithoutEtag) {
            await _fetchSnapshot(currentGen, forceWithoutEtag: true);
            return;
          } else {
            const protocolFailure = ApiFailure(
              'Lỗi giao thức máy chủ: 304 không có dữ liệu',
              statusCode: 502,
            );
            emit(state.copyWith(
                snapshotState: const RequestFailure(protocolFailure)));
            return;
          }
        }

        emit(state.copyWith(
          snapshotState: RequestSuccess(reply),
          isStale: false,
        ));
        _scheduleNextPoll(currentGen);
    }
  }

  void _scheduleNextPoll(int currentGen) {
    if (!state.isForeground || _generation != currentGen) return;

    _pollingTimer?.cancel();
    final intervalMs = state.descriptor?.refreshIntervalMs ?? 12000;
    final intervalSeconds = math.max(3, (intervalMs / 1000).round());

    _pollingTimer = _clock.schedule(
      Duration(seconds: intervalSeconds),
      () {
        // While the descriptor has not been recovered yet, a cycle first
        // retries the descriptor stage; it continues straight to the
        // snapshot, so the image keeps refreshing either way (T02).
        if (state.descriptor == null) {
          _loadDescriptor(currentGen);
        } else {
          _fetchSnapshot(currentGen);
        }
      },
    );
  }

  /// Schedules [onRetry] after a failure, honouring the retry policy:
  /// 401/403/404/422 and other non-retryable failures stop the chain, 429
  /// respects Retry-After (with a 60-second floor), and other retryable
  /// failures use the backoff intervals. [onRetry] must redo the exact
  /// loading stage that failed, so recovery cannot stall on a later stage
  /// whose inputs do not exist yet (T02).
  void _handleFailure(
    Failure failure,
    int currentGen, {
    required Future<void> Function() onRetry,
  }) {
    if (!state.isForeground || _generation != currentGen) return;

    int? statusCode;
    Duration? retryAfter;
    bool retryable = true;

    if (failure is ApiFailure) {
      statusCode = failure.statusCode;
      retryAfter = failure.retryAfter;
      retryable = failure.retryable;
    }

    // Stop polling for non-retryable 4xx auth/not found errors
    if (statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 404 ||
        statusCode == 422 ||
        !retryable) {
      return;
    }

    final Duration delay;
    if (statusCode == 429) {
      final requestedAfter = retryAfter ?? const Duration(seconds: 60);
      delay = requestedAfter < const Duration(seconds: 60)
          ? const Duration(seconds: 60)
          : requestedAfter;
    } else {
      final index = math.min(_retryAttempt, _backoffIntervals.length - 1);
      delay = Duration(seconds: _backoffIntervals[index]);
      _retryAttempt++;
    }

    _pollingTimer?.cancel();
    _pollingTimer = _clock.schedule(delay, () {
      onRetry();
    });
  }

  void setForeground(bool isForeground) {
    if (state.isForeground == isForeground) return;

    emit(state.copyWith(isForeground: isForeground));

    if (!isForeground) {
      _generation++;
      _cancelToken?.cancel('App entered background');
      _cancelToken = null;
      _pollingTimer?.cancel();
      _isInFlight = false;
    } else {
      if (state.cameraId != null) {
        _cancelToken = CancelToken();
        _pollingTimer?.cancel();
        _isInFlight = false;
        _resumeFromMissingStep();
      }
    }
  }

  /// Continues loading from whichever stage is still missing: detail when
  /// there is no camera yet, descriptor when no snapshot endpoint is known,
  /// otherwise the snapshot itself. Shared by foreground resume and the
  /// manual retry so both recover through the exact same chain (T02).
  Future<void> _resumeFromMissingStep() async {
    final id = state.cameraId;
    if (id == null) return;
    if (state.camera == null) {
      await open(id);
    } else if (_currentSnapshotEndpoint().isNotEmpty) {
      await _fetchSnapshot(_generation);
    } else {
      await _loadDescriptor(_generation);
    }
  }

  void notifyViewerOrientationChange() {
    // Retain single chain; does not duplicate polling
  }

  Future<void> retry() async {
    if (_isInFlight) return;
    _pollingTimer?.cancel();
    await _resumeFromMissingStep();
  }

  void dismiss() {
    _generation++;
    _cancelToken?.cancel('Preview dismissed');
    _pollingTimer?.cancel();
    _isInFlight = false;
    emit(CameraPreviewState(isForeground: state.isForeground));
  }

  @override
  Future<void> close() {
    _generation++;
    _cancelToken?.cancel('Cubit closed');
    _pollingTimer?.cancel();
    _isInFlight = false;
    return super.close();
  }
}
