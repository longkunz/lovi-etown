import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_config.dart';
import '../../../../config/map_config.dart';
import '../../../../services/camera_api_client.dart';
import '../../data/repositories/api_camera_map_repository.dart';
import '../../data/repositories/fixture_camera_map_repository.dart';
import '../../data/repositories/local_favorites_repository.dart';
import '../../data/geolocator_camera_location_gateway.dart';
import '../../domain/camera_map_repository.dart';
import '../../domain/camera_location_gateway.dart';
import '../../domain/camera_models.dart';
import '../../domain/camera_repository.dart';
import '../../domain/favorites_repository.dart';
import '../camera_feature.dart';
import '../camera_feature_scope.dart';
import '../widgets/camera_map_view_config.dart';
import 'camera_map_screen.dart';

class CameraNavigationShell extends StatefulWidget {
  const CameraNavigationShell(
      {required this.navigationShell,
      this.cameraRepository,
      this.favoritesRepository,
      super.key});
  final StatefulNavigationShell navigationShell;
  final CameraRepository? cameraRepository;
  final FavoritesRepository? favoritesRepository;
  @override
  State<CameraNavigationShell> createState() => _CameraNavigationShellState();
}

class _CameraNavigationShellState extends State<CameraNavigationShell> {
  late final CameraRepository _repository;
  late final FavoritesRepository _favorites;
  late final bool _configured;
  @override
  void initState() {
    super.initState();
    _configured = AppConfig.isConfigured;
    if (_configured) {
      _repository = resolveCameraRepository(widget.cameraRepository);
      _favorites = resolveFavoritesRepository(widget.favoritesRepository);
    }
  }

  bool _covered = false;
  void _openCamera(Camera camera) async {
    if (_covered) return;
    setState(() => _covered = true);
    // Native map must leave the tree before the next route owns one.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await context.push('/camera/${Uri.encodeComponent(camera.id)}',
          extra: CameraViewerDependencies(_repository, _favorites));
    } finally {
      if (mounted) setState(() => _covered = false);
    }
  }

  @override
  void dispose() {
    if (_configured &&
        widget.favoritesRepository == null &&
        _favorites is LocalFavoritesRepository) {
      _favorites.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    final visible = !_covered && (ModalRoute.isCurrentOf(context) ?? true);
    final body = !_configured
        ? widget.navigationShell
        : CameraFeatureScope(
            repository: _repository,
            favorites: _favorites,
            mapActive: visible && index == 0,
            cameraActive: visible && index == 1,
            openCamera: _openCamera,
            openCameras: () => widget.navigationShell.goBranch(1),
            child: widget.navigationShell);
    return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (next) {
              if (next != index) widget.navigationShell.goBranch(next);
            },
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map),
                  label: 'navigation.map'.tr()),
              NavigationDestination(
                  icon: const Icon(Icons.videocam_outlined),
                  selectedIcon: const Icon(Icons.videocam),
                  label: 'navigation.cameras'.tr()),
            ]));
  }
}

/// Map branch dependencies are resolved once and never initialize a catalog cubit.
class CameraMapFeature extends StatefulWidget {
  const CameraMapFeature(
      {this.repository,
      this.locationGateway,
      this.mapBuilder,
      this.connectionConfig,
      super.key});
  final CameraMapRepository? repository;
  final CameraLocationGateway? locationGateway;
  final CameraMapViewBuilder? mapBuilder;
  final MapConnectionConfig? connectionConfig;
  @override
  State<CameraMapFeature> createState() => _CameraMapFeatureState();
}

class _CameraMapFeatureState extends State<CameraMapFeature> {
  late final CameraMapRepository _repository = widget.repository ??
      (AppConfig.cameraConfig.demoMode
          ? FixtureCameraMapRepository()
          : ApiCameraMapRepository(CameraApiClient(
              dio: AppConfig.dio, config: AppConfig.cameraConfig)));
  late final CameraLocationGateway _location =
      widget.locationGateway ?? GeolocatorCameraLocationGateway();
  late final MapConnectionConfig _config =
      widget.connectionConfig ?? MapConnectionConfig.fromEnvironment();
  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) return const CameraNotConfiguredScreen();
    final scope = CameraFeatureScope.maybeOf(context)!;
    return CameraMapScreen(
        repository: _repository,
        locationGateway: _location,
        cameraRepository: scope.repository,
        onSelectCamera: scope.openCamera,
        onOpenCameras: scope.openCameras,
        active: scope.mapActive,
        mapBuilder: widget.mapBuilder,
        connectionConfig: _config,
        isDemoMode: AppConfig.cameraConfig.demoMode);
  }
}
