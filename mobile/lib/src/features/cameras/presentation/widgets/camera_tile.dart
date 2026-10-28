import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

class CameraTile extends StatelessWidget {
  const CameraTile({
    required this.camera,
    this.viewMode = CameraViewMode.card,
    this.isFavorite = false,
    this.thumbnailBytes,
    this.onTap,
    this.onToggleFavorite,
    super.key,
  });

  final Camera camera;
  final CameraViewMode viewMode;
  final bool isFavorite;
  final Uint8List? thumbnailBytes;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    switch (viewMode) {
      case CameraViewMode.card:
        return _buildCard(context);
      case CameraViewMode.grid:
        return _buildGrid(context);
      case CameraViewMode.list:
        return _buildList(context);
    }
  }

  Widget _buildThumbnail(
      {required double height, double? width, BoxFit fit = BoxFit.cover}) {
    // If real thumbnail bytes are provided from cache/scheduler
    Widget imageWidget;
    if (thumbnailBytes != null && thumbnailBytes!.isNotEmpty) {
      imageWidget = Image.memory(
        thumbnailBytes!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) =>
            _buildPlaceholder(height: height, width: width),
      );
    } else if (camera.thumbnailEndpoint != null &&
        camera.thumbnailEndpoint!.startsWith('assets/')) {
      imageWidget = Image.asset(
        camera.thumbnailEndpoint!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) =>
            _buildPlaceholder(height: height, width: width),
      );
    } else {
      // Default fixture image placeholder
      imageWidget = Image.asset(
        'assets/images/placeholder.jpg',
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) =>
            _buildPlaceholder(height: height, width: width),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
      child: Container(
        height: height,
        width: width,
        color: CameraUiTokens.surfaceDark.withValues(alpha: 0.1),
        child: imageWidget,
      ),
    );
  }

  Widget _buildPlaceholder({required double height, double? width}) {
    return Container(
      height: height,
      width: width,
      color: Colors.black12,
      child: const Center(
        child: Icon(
          Icons.videocam_outlined,
          color: CameraUiTokens.primaryTeal,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildLiveBadge({bool compact = false}) {
    return Container(
      key: ValueKey('live_badge_${camera.id}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : CameraUiTokens.spacing8,
        vertical: compact ? 2 : CameraUiTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: CameraUiTokens.errorRed,
        borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fiber_manual_record,
            size: 8,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'TRỰC TIẾP',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassFavoriteButton(BuildContext context) {
    final foreground = Theme.of(context).brightness == Brightness.light
        ? CameraUiTokens.controlForegroundLight
        : CameraUiTokens.controlForegroundDark;
    return Semantics(
      label: isFavorite ? 'camera.unfavorite'.tr() : 'camera.favorite'.tr(),
      selected: isFavorite,
      child: SizedBox.square(
        dimension: CameraUiTokens.minTouchTarget,
        child: IconButton(
          tooltip: isFavorite ? 'camera.unfavorite'.tr() : 'camera.favorite'.tr(),
          padding: EdgeInsets.zero,
          onPressed: onToggleFavorite,
          icon: CameraGlassSurface(
            role: CameraGlassRole.control,
            borderRadius:
                BorderRadius.circular(CameraUiTokens.overlayControlSize / 2),
            child: SizedBox.square(
              dimension: CameraUiTokens.overlayControlSize,
              child: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                size: CameraUiTokens.controlIconSize,
                color: isFavorite ? CameraUiTokens.starActive : foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return CameraGlassIconButton(
      icon: isFavorite ? Icons.star : Icons.star_border,
      label: isFavorite ? 'camera.unfavorite'.tr() : 'camera.favorite'.tr(),
      selected: isFavorite,
      embedded: true,
      onPressed: onToggleFavorite,
      size: CameraUiTokens.minTouchTarget,
      iconSize: CameraUiTokens.controlIconSize,
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing16,
        vertical: CameraUiTokens.spacing8,
      ),
      child: CameraGlassSurface(
        key: ValueKey('camera_card_${camera.id}'),
        borderRadius: BorderRadius.circular(CameraUiTokens.radius16),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _buildThumbnail(height: 190, width: double.infinity),
                  if (camera.canLive)
                    Positioned(
                      top: CameraUiTokens.spacing8,
                      left: CameraUiTokens.spacing8,
                      child: _buildLiveBadge(),
                    ),
                  Positioned(
                    top: CameraUiTokens.spacing8,
                    right: CameraUiTokens.spacing8,
                    child: _buildGlassFavoriteButton(context),
                  ),
                  if (camera.district != null && camera.district!.isNotEmpty)
                    Positioned(
                      bottom: CameraUiTokens.spacing8,
                      left: CameraUiTokens.spacing8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CameraUiTokens.spacing8,
                          vertical: CameraUiTokens.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: CameraUiTokens.primaryTealDark
                              .withValues(alpha: 0.85),
                          borderRadius:
                              BorderRadius.circular(CameraUiTokens.radius8),
                        ),
                        child: Text(
                          camera.district!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(CameraUiTokens.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (camera.address != null &&
                        camera.address!.isNotEmpty) ...[
                      const SizedBox(height: CameraUiTokens.spacing4),
                      Text(
                        camera.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w600,
    );
    // Reserve two lines even for short names to align thumbnails and labels.
    final nameMetrics = TextPainter(
      text: TextSpan(text: camera.name, style: nameStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final nameHeight = nameMetrics.preferredLineHeight * 2;
    nameMetrics.dispose();
    return CameraGlassSurface(
      key: ValueKey('camera_grid_${camera.id}'),
      borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(
                      height: double.infinity, width: double.infinity),
                  if (camera.canLive)
                    Positioned(
                      top: CameraUiTokens.spacing8,
                      left: CameraUiTokens.spacing8,
                      child: _buildLiveBadge(compact: true),
                    ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: _buildGlassFavoriteButton(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(CameraUiTokens.spacing8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: nameHeight,
                    child: Text(
                      camera.name,
                      style: nameStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: CameraUiTokens.spacing2),
                  Text(
                    camera.district ?? '',
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
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing16,
        vertical: CameraUiTokens.spacing4,
      ),
      child: CameraGlassSurface(
        key: ValueKey('camera_list_${camera.id}'),
        borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
          child: Padding(
          padding: const EdgeInsets.all(CameraUiTokens.spacing8),
          child: Row(
            children: [
              _buildThumbnail(height: 64, width: 96),
              const SizedBox(width: CameraUiTokens.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            camera.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (camera.canLive) ...[
                          const SizedBox(width: CameraUiTokens.spacing8),
                          _buildLiveBadge(compact: true),
                        ],
                      ],
                    ),
                    if (camera.district != null &&
                        camera.district!.isNotEmpty) ...[
                      const SizedBox(height: CameraUiTokens.spacing2),
                      Text(
                        camera.district!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: CameraUiTokens.primaryTeal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _buildFavoriteButton(),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
