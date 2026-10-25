import 'package:flutter/widgets.dart';
import '../domain/camera_models.dart';
import '../domain/camera_repository.dart';
import '../domain/favorites_repository.dart';

/// Passed through a root viewer route so changes to favorites reach both tabs.
class CameraViewerDependencies {
  const CameraViewerDependencies(this.repository, this.favorites);
  final CameraRepository repository;
  final FavoritesRepository favorites;
}

class CameraFeatureScope extends InheritedWidget {
  const CameraFeatureScope(
      {required this.repository,
      required this.favorites,
      required this.mapActive,
      required this.cameraActive,
      required this.openCamera,
      required this.openCameras,
      required super.child,
      super.key});
  final CameraRepository repository;
  final FavoritesRepository favorites;
  final bool mapActive, cameraActive;
  final ValueChanged<Camera> openCamera;
  final VoidCallback openCameras;
  static CameraFeatureScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CameraFeatureScope>();
  @override
  bool updateShouldNotify(CameraFeatureScope old) =>
      mapActive != old.mapActive ||
      cameraActive != old.cameraActive ||
      repository != old.repository ||
      favorites != old.favorites;
}
