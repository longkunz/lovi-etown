import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_state.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_directions.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_image_viewer.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_live_player.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/traffic_brief_card.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_refresh_countdown.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<void> showCameraSnapshotSheet(
  BuildContext context, {
  required String cameraId,
  required CameraPreviewCubit preview,
  required FavoritesRepository favorites,
  CameraRepository? repository,
}) {
  preview.open(cameraId);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return CameraSnapshotSheet(
        preview: preview,
        favorites: favorites,
        repository: repository,
      );
    },
  );
}

class CameraSnapshotSheet extends StatefulWidget {
  const CameraSnapshotSheet({
    required this.preview,
    required this.favorites,
    this.repository,
    super.key,
  });

  final CameraPreviewCubit preview;
  final FavoritesRepository favorites;

  /// Optional: enables the traffic brief card (T17) when provided.
  final CameraRepository? repository;

  @override
  State<CameraSnapshotSheet> createState() => _CameraSnapshotSheetState();
}

class _CameraSnapshotSheetState extends State<CameraSnapshotSheet>
    with WidgetsBindingObserver {
  StreamSubscription<List<FavoriteCamera>>? _favSub;
  Set<String> _favoriteIds = {};

  // T14: live HLS mode for cameras whose DTO carries a stream URL.
  bool _liveMode = false;
  bool _liveFailed = false;

  // T17: switching cameras inside the sheet (via the brief card) resets
  // the live-mode state for the newly opened camera.
  String? _mediaCameraId;

  void _handleLiveUnavailable() {
    if (!mounted) return;
    setState(() {
      _liveFailed = true;
      _liveMode = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _favSub = widget.favorites.watch().listen((favs) {
      if (mounted) {
        setState(() {
          _favoriteIds = favs.map((f) => f.id).toSet();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    widget.preview.setForeground(isForeground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.preview.dismiss();
    _favSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final isDark = theme.brightness == Brightness.dark;

    return AdaptiveGlass(
      shape: const LiquidRoundedSuperellipse(
        borderRadius: CameraUiTokens.radius20,
      ),
      settings: LiquidGlassSettings(
        blur: CameraUiTokens.glassSheetBlur,
        thickness: 16,
        glassColor: isDark ? const Color(0x26004D40) : const Color(0x1A00796B),
        ambientStrength: 0.1,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: isDark
              ? CameraUiTokens.surfaceDark.withValues(alpha: CameraUiTokens.glassOpacityDark)
              : CameraUiTokens.surfaceLight.withValues(alpha: CameraUiTokens.glassOpacityLight),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(CameraUiTokens.radius20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BlocBuilder<CameraPreviewCubit, CameraPreviewState>(
          bloc: widget.preview,
          builder: (context, state) {
            final camera = state.camera;
            final isFavorite =
                camera != null && _favoriteIds.contains(camera.id);
            if (camera != null && _mediaCameraId != camera.id) {
              _mediaCameraId = camera.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _liveMode = false;
                    _liveFailed = false;
                  });
                }
              });
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin:
                          const EdgeInsets.only(top: CameraUiTokens.spacing8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(CameraUiTokens.radiusFull),
                      ),
                    ),
                  ),

                  // Header with Close, Title, Favorite Star
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraUiTokens.spacing8,
                      vertical: CameraUiTokens.spacing4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: CameraUiTokens.minTouchTarget,
                          height: CameraUiTokens.minTouchTarget,
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            camera?.name ?? '...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (camera != null)
                          SizedBox(
                            width: CameraUiTokens.minTouchTarget,
                            height: CameraUiTokens.minTouchTarget,
                            child: IconButton(
                              onPressed: () {
                                widget.favorites.setSaved(camera, !isFavorite);
                              },
                              icon: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                  size: CameraUiTokens.controlIconSize,
                                color: isFavorite
                                    ? CameraUiTokens.starActive
                                    : CameraUiTokens.starInactive,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // District/address subtitle if available
                  if (camera?.district != null || camera?.address != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CameraUiTokens.spacing16,
                      ),
                      child: Text(
                        camera?.address ?? camera?.district ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: CameraUiTokens.primaryTeal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const SizedBox(height: CameraUiTokens.spacing8),

                  // Media area: snapshot polling by default; a live HLS
                  // player when the camera supports it and the user
                  // switches to "Trực tiếp" (T14). A live failure falls
                  // back to the snapshot with a note.
                  Padding(
                    padding: const EdgeInsets.all(CameraUiTokens.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (camera != null && camera.canLive) ...[
                          SegmentedButton<bool>(
                            key: const ValueKey('live_mode_toggle'),
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.image_outlined),
                                label: Text('Ảnh tĩnh'),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.live_tv_outlined),
                                label: Text('Trực tiếp'),
                              ),
                            ],
                            selected: {_liveMode},
                            onSelectionChanged: (selection) {
                              setState(() => _liveMode = selection.first);
                            },
                          ),
                          const SizedBox(height: CameraUiTokens.spacing12),
                        ],
                        if (_liveFailed) ...[
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: CameraUiTokens.errorRed,
                              ),
                              SizedBox(width: CameraUiTokens.spacing4),
                              Expanded(
                                child: Text(
                                  'Không phát được trực tiếp — đang hiện ảnh tĩnh',
                                  style: TextStyle(
                                    color: CameraUiTokens.errorRed,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: CameraUiTokens.spacing8),
                        ],
                        if (_liveMode && camera != null && camera.canLive)
                          CameraLivePlayer(
                            key: ValueKey('live_player_${camera.id}'),
                            streamUrl: camera.streamUrl!,
                            onUnavailable: _handleLiveUnavailable,
                          )
                        else
                          _buildSnapshotContent(context, state),
                      ],
                    ),
                  ),

                  // Directions handoff (T10) — only when the catalog
                  // provided coordinates for this camera.
                  if (camera != null && camera.hasLocation)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CameraUiTokens.spacing16,
                        0,
                        CameraUiTokens.spacing16,
                        CameraUiTokens.spacing16,
                      ),
                      child: OutlinedButton.icon(
                        key: const ValueKey('directions_button'),
                        onPressed: () => openCameraDirections(camera),
                        icon: const Icon(Icons.directions),
                        label: const Text('Chỉ đường'),
                      ),
                    ),

                  // Traffic brief (T17) — rendered when a repository is
                  // available; the card hides itself without data.
                  if (camera != null && widget.repository != null)
                    TrafficBriefCard(
                      key: ValueKey('traffic_brief_${camera.id}'),
                      camera: camera,
                      repository: widget.repository!,
                      onSelectCamera: (related) =>
                          widget.preview.open(related.id),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildSnapshotContent(BuildContext context, CameraPreviewState state) {
    if (state.snapshotState.isLoading && state.currentFrame == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (state.snapshotState.isFailure && state.currentFrame == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image,
                size: 40, color: CameraUiTokens.errorRed),
            const SizedBox(height: CameraUiTokens.spacing8),
            const Text('Không thể tải hình ảnh camera'),
            const SizedBox(height: CameraUiTokens.spacing8),
            ElevatedButton(
              onPressed: widget.preview.retry,
              child: Text('shared.retry'.tr()),
            ),
          ],
        ),
      );
    }

    final frame = state.currentFrame;
    Widget imageWidget;
    if (frame != null && frame.bytes.isNotEmpty) {
      imageWidget = Image.memory(
        frame.bytes,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else if (state.camera?.thumbnailEndpoint != null &&
        state.camera!.thumbnailEndpoint!.startsWith('assets/')) {
      imageWidget = Image.asset(
        state.camera!.thumbnailEndpoint!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      imageWidget = _buildPlaceholder();
    }

    return GestureDetector(
      key: const ValueKey('snapshot_sheet_image'),
      onTap: () {
        showCameraImageViewer(context, preview: widget.preview);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 300,
            minHeight: 180,
          ),
          width: double.infinity,
          color: Colors.black12,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              imageWidget,
                if (state.currentFrame != null)
                  Positioned(
                    bottom: CameraUiTokens.spacing8,
                    left: CameraUiTokens.spacing8,
                    right: CameraUiTokens.spacing8,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: CameraRefreshCountdown(state: state),
                    ),
                  ),
              if (state.isStale)
                Positioned(
                  top: CameraUiTokens.spacing8,
                  left: CameraUiTokens.spacing8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraUiTokens.spacing8,
                      vertical: CameraUiTokens.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius:
                          BorderRadius.circular(CameraUiTokens.radius8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Ảnh cũ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        Icons.videocam_outlined,
        color: CameraUiTokens.primaryTeal,
        size: 48,
      ),
    );
  }
}
