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
                'Vui lòng kiểm tra cấu hình kết nối máy chủ.',
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
/// Acts as route destination for AppRoutes.camera ('/').
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

    return CameraScreen(
      cameraRepository: resolveCameraRepository(cameraRepository),
      favoritesRepository: resolveFavoritesRepository(favoritesRepository),
      catalogCubit: catalogCubit,
      isDemoMode: AppConfig.cameraConfig.demoMode,
    );
  }
}

/// Entry point for the single-camera viewer route
/// (AppRoutes.cameraViewer, '/camera/:id'). Builds the viewer with the
/// same repositories [CameraFeature] resolves.
class CameraViewerFeature extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!AppConfig.isConfigured) {
      return const CameraNotConfiguredScreen();
    }

    final repo = resolveCameraRepository(cameraRepository);
    final favRepo = resolveFavoritesRepository(favoritesRepository);

    return CameraViewerScreen(
      cameraId: cameraId,
      repository: repo,
      favoritesRepository: favRepo,
      onOpenMultiCamera: () async {
        final favorites = await favRepo.watch().first;
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MultiCameraScreen(
              favorites: favorites,
              repository: repo,
              favoritesRepository: favRepo,
            ),
          ),
        );
      },
    );
  }
}
