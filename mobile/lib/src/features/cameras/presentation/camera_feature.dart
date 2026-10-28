import 'camera_feature_scope.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/data/datasources/favorites_local_store.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/api_camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/fixture_camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/local_favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/services/camera_api_client.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_viewer_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/multi_camera_screen.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

/// Resolves the camera repository the same way for every camera-feature
/// entry point: an explicit override wins, otherwise the fixture
/// repository in demo mode or the API repository against the backend.
CameraRepository resolveCameraRepository(CameraRepository? override) {
  return override ??
      (AppConfig.cameraConfig.demoMode
          ? FixtureCameraRepository()
          : ApiCameraRepository(
              apiClient: CameraApiClient(
                dio: AppConfig.dio,
                config: AppConfig.cameraConfig,
              ),
            ));
}

/// Resolves the favorites repository (local storage) unless overridden.
FavoritesRepository resolveFavoritesRepository(FavoritesRepository? override) {
  return override ??
      LocalFavoritesRepository(store: SharedPreferencesFavoritesLocalStore());
}

/// Shown when the camera backend configuration is missing entirely.
class CameraNotConfiguredScreen extends StatelessWidget {
  const CameraNotConfiguredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CameraUiTokens.backgroundLight,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(CameraUiTokens.spacing24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: CameraUiTokens.errorRed,
              ),
              const SizedBox(height: CameraUiTokens.spacing16),
              Text(
                'shared.connection_error'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CameraUiTokens.spacing8),
              Text(
                'camera.check_server_config'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point widget for the Camera feature.
/// Acts as route destination for AppRoutes.camera ('/cameras').
class CameraFeature extends StatelessWidget {
  const CameraFeature({
    this.cameraRepository,
    this.favoritesRepository,
    this.catalogCubit,
    super.key,
  });

  final CameraRepository? cameraRepository;
  final FavoritesRepository? favoritesRepository;
  final CameraCatalogCubit? catalogCubit;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return const CameraNotConfiguredScreen();
    }

    final scope = CameraFeatureScope.maybeOf(context);
    return CameraScreen(
      cameraRepository: cameraRepository ??
          scope?.repository ??
          resolveCameraRepository(null),
      favoritesRepository: favoritesRepository ??
          scope?.favorites ??
          resolveFavoritesRepository(null),
      active: scope?.cameraActive ?? true,
      onSelectCamera: scope?.openCamera,
      catalogCubit: catalogCubit,
      isDemoMode: AppConfig.cameraConfig.demoMode,
    );
  }
}

/// Entry point for the single-camera viewer route
/// (AppRoutes.cameraViewer, '/camera/:id'). Builds the viewer with the
/// same repositories [CameraFeature] resolves.
class CameraViewerFeature extends StatefulWidget {
  const CameraViewerFeature({
    required this.cameraId,
    this.cameraRepository,
    this.favoritesRepository,
    super.key,
  });

  final String cameraId;
  final CameraRepository? cameraRepository;
  final FavoritesRepository? favoritesRepository;

  @override
  State<CameraViewerFeature> createState() => _CameraViewerFeatureState();
}

class _CameraViewerFeatureState extends State<CameraViewerFeature> {
  CameraRepository? _repository;
  FavoritesRepository? _favoritesRepository;
  FutureEither<void>? _favoritesReady;
  LocalFavoritesRepository? _ownedFavorites;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  @override
  void didUpdateWidget(CameraViewerFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_repository == null ||
        oldWidget.cameraRepository != widget.cameraRepository ||
        oldWidget.favoritesRepository != widget.favoritesRepository) {
      _disposeFavorites();
      _initializeRepositories();
    }
  }

  void _initializeRepositories() {
    if (!AppConfig.isConfigured) return;
    _repository = resolveCameraRepository(widget.cameraRepository);
    _favoritesRepository =
        resolveFavoritesRepository(widget.favoritesRepository);
    _ownedFavorites = widget.favoritesRepository == null
        ? _favoritesRepository as LocalFavoritesRepository
        : null;
    _favoritesReady = _favoritesRepository!.load();
  }

  void _disposeFavorites() {
    _ownedFavorites?.dispose();
    _ownedFavorites = null;
  }

  @override
  void dispose() {
    _disposeFavorites();
    super.dispose();
  }

  Widget _buildFavoritesFailure(String message) {
    return Scaffold(
      backgroundColor: CameraUiTokens.backgroundDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: CameraUiTokens.spacing12),
            ElevatedButton(
              key: const ValueKey('viewer_favorites_retry'),
              onPressed: () => setState(() {
                _favoritesReady = _favoritesRepository!.load();
              }),
              child: Text('shared.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return const CameraNotConfiguredScreen();
    }

    return FutureBuilder(
      future: _favoritesReady,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFavoritesFailure('camera.favorites_load_error'.tr());
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: CameraUiTokens.backgroundDark,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!.fold(
          (_) => _buildFavoritesFailure('camera.favorites_load_error'.tr()),
          (_) => CameraViewerScreen(
            key: ValueKey((widget.cameraId, _repository, _favoritesRepository)),
            cameraId: widget.cameraId,
            repository: _repository!,
            favoritesRepository: _favoritesRepository!,
            onOpenMultiCamera: () async {
              final favorites = await _favoritesRepository!.watch().first;
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MultiCameraScreen(
                    favorites: favorites,
                    repository: _repository!,
                    favoritesRepository: _favoritesRepository!,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
