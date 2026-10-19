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

    final detailResult =
        await _repository.detail(id, cancelToken: _cancelToken);
    if (_generation != currentGen) return;

    await detailResult.fold(
      (failure) async {
        emit(state.copyWith(
          cameraState: RequestFailure(failure),
          snapshotState: RequestFailure(failure),
        ));
        _handleFailure(failure, currentGen);
      },
      (camera) async {
        emit(state.copyWith(
          camera: camera,
          cameraState: RequestSuccess(camera),
        ));

        // Fetch playback descriptor
        final playbackResult =
            await _repository.playback(id, cancelToken: _cancelToken);
        if (_generation != currentGen) return;

        await playbackResult.fold(
          (failure) async {
            // Playback descriptor failed, but snapshot endpoint might exist on camera
            await _fetchSnapshot(currentGen);
          },
          (descriptor) async {
            emit(state.copyWith(descriptor: descriptor));
            await _fetchSnapshot(currentGen);
          },
        );
      },
    );
  }

  Future<void> _fetchSnapshot(int currentGen,
      {bool forceWithoutEtag = false}) async {
    if (_generation != currentGen || !state.isForeground) return;
    if (_isInFlight) return;

    _isInFlight = true;

    final descriptorEndpoint = (state.descriptor != null &&
            state.descriptor!.cameraId == state.cameraId)
        ? state.descriptor!.snapshotEndpoint
        : null;
    final cameraEndpoint =
        (state.camera != null && state.camera!.id == state.cameraId)
            ? (state.camera!.snapshotEndpoint ??
                state.camera!.thumbnailEndpoint)
            : null;

    final endpoint = descriptorEndpoint ?? cameraEndpoint ?? '';

    if (endpoint.isEmpty) {
      _isInFlight = false;
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

      // Stale check
      final isStale = state.currentFrame?.fetchedAt != null &&
          _clock.now().difference(state.currentFrame!.fetchedAt!).inSeconds >
              60;

      emit(state.copyWith(
        snapshotState: RequestFailure(failure),
        isStale: isStale,
      ));

      _handleFailure(failure, currentGen);
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
      () => _fetchSnapshot(currentGen),
    );
  }

  void _handleFailure(Failure failure, int currentGen) {
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
    _pollingTimer = _clock.schedule(delay, () => _fetchSnapshot(currentGen));
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
        if (state.camera == null) {
          open(state.cameraId!);
        } else {
          _fetchSnapshot(_generation);
        }
      }
    }
  }

  void notifyViewerOrientationChange() {
    // Retain single chain; does not duplicate polling
  }

  Future<void> retry() async {
    if (_isInFlight) return;
    _pollingTimer?.cancel();

    if (state.cameraId != null) {
      if (state.camera == null) {
        await open(state.cameraId!);
      } else {
        await _fetchSnapshot(_generation);
      }
    }
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
