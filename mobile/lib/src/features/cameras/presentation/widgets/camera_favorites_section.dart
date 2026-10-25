import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

class CameraFavoritesSection extends StatelessWidget {
  const CameraFavoritesSection({
    required this.favorites,
    this.onSelectCamera,
    this.onToggleFavorite,
    this.onExploreCameras,
    this.onViewGrid,
    super.key,
  });

  final List<FavoriteCamera> favorites;
  final ValueChanged<Camera>? onSelectCamera;
  final ValueChanged<Camera>? onToggleFavorite;
  final VoidCallback? onExploreCameras;

  /// Opens the multi-camera grid (T12); shown when there are 2+ favorites.
  final VoidCallback? onViewGrid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing16,
        vertical: CameraUiTokens.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Icon(
                Icons.star,
                color: CameraUiTokens.starActive,
                size: 20,
              ),
              const SizedBox(width: CameraUiTokens.spacing8),
              Expanded(
                child: Text(
                  'camera.favorites_title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (favorites.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CameraUiTokens.spacing8,
                    vertical: CameraUiTokens.spacing2,
                  ),
                  decoration: BoxDecoration(
                    color: CameraUiTokens.primaryTeal.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(CameraUiTokens.radiusFull),
                  ),
                  child: Text(
                    '${favorites.length}',
                    style: const TextStyle(
                      color: CameraUiTokens.primaryTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (onViewGrid != null && favorites.length >= 2)
                IconButton(
                  key: const ValueKey('view_grid_button'),
                  icon: const Icon(
                    Icons.grid_view,
                    color: CameraUiTokens.primaryTeal,
                    size: 20,
                  ),
                  tooltip: 'Xem lưới',
                  constraints: const BoxConstraints(
                    minWidth: CameraUiTokens.minTouchTarget,
                    minHeight: CameraUiTokens.minTouchTarget,
                  ),
                  onPressed: onViewGrid,
                ),
            ],
          ),
          const SizedBox(height: CameraUiTokens.spacing8),

          // Content
          if (favorites.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(CameraUiTokens.spacing16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Text(
                  'camera.empty_favorites'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: CameraUiTokens.favoriteCardBaseHeight +
                  MediaQuery.textScalerOf(context)
                      .scale(CameraUiTokens.favoriteCardTextHeight) -
                  CameraUiTokens.favoriteCardTextHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: favorites.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: CameraUiTokens.spacing8),
                itemBuilder: (context, index) {
                  final fav = favorites[index];
                  return Container(
                    width: 180,
                    padding: const EdgeInsets.all(CameraUiTokens.spacing8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(CameraUiTokens.radius12),
                      border: Border.all(
                        color: fav.isMissingFromCatalog
                            ? CameraUiTokens.errorRed.withValues(alpha: 0.4)
                            : theme.dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (onSelectCamera != null) {
                          onSelectCamera!(
                            Camera(
                              id: fav.id,
                              name: fav.name,
                              provinceId: 'tp_hcm',
                              district: fav.district,
                              address: fav.address,
                              snapshotCapable: true,
                              playbackEndpoint: '',
                            ),
                          );
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fav.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              CameraGlassIconButton(
                                embedded: true,
                                icon: Icons.star,
                                label: 'Bỏ quan tâm',
                                selected: true,
                                iconSize: 20,
                                onPressed: () {
                                  if (onToggleFavorite != null) {
                                    onToggleFavorite!(
                                      Camera(
                                        id: fav.id,
                                        name: fav.name,
                                        provinceId: 'tp_hcm',
                                        district: fav.district,
                                        playbackEndpoint: '',
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (fav.isMissingFromCatalog)
                            Text(
                              'Đã gỡ khỏi danh mục',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: CameraUiTokens.errorRed,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (fav.district != null)
                            Text(
                              fav.district!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: CameraUiTokens.primaryTeal,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
