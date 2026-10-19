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
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

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

    final repo = cameraRepository ??
        (AppConfig.cameraConfig.demoMode
            ? FixtureCameraRepository()
            : ApiCameraRepository(
                apiClient: CameraApiClient(
                  dio: AppConfig.dio,
                  config: AppConfig.cameraConfig,
                ),
              ));
    final favRepo = favoritesRepository ??
        LocalFavoritesRepository(store: SharedPreferencesFavoritesLocalStore());

    return CameraScreen(
      cameraRepository: repo,
      favoritesRepository: favRepo,
      catalogCubit: catalogCubit,
      isDemoMode: AppConfig.cameraConfig.demoMode,
    );
  }
}
