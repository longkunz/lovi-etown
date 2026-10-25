import 'package:equatable/equatable.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/utils/async_state.dart';

class CameraPreviewState extends Equatable {
  const CameraPreviewState({
    this.cameraId,
    this.camera,
    this.descriptor,
    this.currentFrame,
    this.cameraState = const RequestInitial(),
    this.snapshotState = const RequestInitial(),
    this.isStale = false,
    this.isForeground = true,
    this.nextRefreshAt,
    this.refreshDelay,
  });

  final String? cameraId;
  final Camera? camera;
  final PlaybackDescriptor? descriptor;
  final SnapshotFrame? currentFrame;
  final RequestState<Camera> cameraState;
  final RequestState<SnapshotReply> snapshotState;
  final bool isStale;
  final bool isForeground;
  final DateTime? nextRefreshAt;
  final Duration? refreshDelay;

  CameraPreviewState copyWith({
    String? cameraId,
    Camera? camera,
    PlaybackDescriptor? descriptor,
    SnapshotFrame? currentFrame,
    RequestState<Camera>? cameraState,
    RequestState<SnapshotReply>? snapshotState,
    bool? isStale,
    bool? isForeground,
    DateTime? nextRefreshAt,
    Duration? refreshDelay,
    bool clearRefreshSchedule = false,
    bool clearCurrentFrame = false,
    bool clearCamera = false,
    bool clearDescriptor = false,
  }) {
    return CameraPreviewState(
      cameraId: cameraId ?? this.cameraId,
      camera: clearCamera ? null : (camera ?? this.camera),
      descriptor: clearDescriptor ? null : (descriptor ?? this.descriptor),
      currentFrame:
          clearCurrentFrame ? null : (currentFrame ?? this.currentFrame),
      cameraState: cameraState ?? this.cameraState,
      snapshotState: snapshotState ?? this.snapshotState,
      isStale: isStale ?? this.isStale,
      isForeground: isForeground ?? this.isForeground,
      nextRefreshAt:
          clearRefreshSchedule ? null : (nextRefreshAt ?? this.nextRefreshAt),
      refreshDelay:
          clearRefreshSchedule ? null : (refreshDelay ?? this.refreshDelay),
    );
  }

  @override
  List<Object?> get props => [
        cameraId,
        camera,
        descriptor,
        currentFrame,
        cameraState,
        snapshotState,
        isStale,
        isForeground,
        nextRefreshAt,
        refreshDelay,
      ];
}
