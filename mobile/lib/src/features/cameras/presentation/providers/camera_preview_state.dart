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
  });

  final String? cameraId;
  final Camera? camera;
  final PlaybackDescriptor? descriptor;
  final SnapshotFrame? currentFrame;
  final RequestState<Camera> cameraState;
  final RequestState<SnapshotReply> snapshotState;
  final bool isStale;
  final bool isForeground;

  CameraPreviewState copyWith({
    String? cameraId,
    Camera? camera,
    PlaybackDescriptor? descriptor,
    SnapshotFrame? currentFrame,
    RequestState<Camera>? cameraState,
    RequestState<SnapshotReply>? snapshotState,
    bool? isStale,
    bool? isForeground,
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
      ];
}
