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
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_refresh_countdown.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_traffic_map_card.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/traffic_brief_card.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

Future<void> showCameraSnapshotSheet(
  BuildContext context, {
  required String cameraId,
  required CameraPreviewCubit preview,
  required FavoritesRepository favorites,
  CameraRepository? repository,
  Widget Function(BuildContext, CameraTrafficMapConfig)? mapBuilder,
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
        mapBuilder: mapBuilder,
      );
    },
  );
}

class CameraSnapshotSheet extends StatefulWidget {
  const CameraSnapshotSheet({
    required this.preview,
    required this.favorites,
    this.repository,
    this.mapBuilder,
    super.key,
  });

  final CameraPreviewCubit preview;
  final FavoritesRepository favorites;

  /// Optional: enables the traffic brief card (T17) when provided.
  final CameraRepository? repository;

  /// Optional: custom map builder for testing (T18).
  final Widget Function(BuildContext, CameraTrafficMapConfig)? mapBuilder;

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
  bool _mapCovered = false;
  bool _routeIsCurrent = true;
  bool _appIsForeground = true;

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
    _appIsForeground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
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
    setState(() => _appIsForeground = state == AppLifecycleState.resumed);
    widget.preview.setForeground(_appIsForeground);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
  }

  Future<void> _openImageViewer() async {
    setState(() => _mapCovered = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await showCameraImageViewer(context, preview: widget.preview);
    } finally {
      if (mounted) setState(() => _mapCovered = false);
    }
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

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color:
            isDark ? CameraUiTokens.surfaceDark : CameraUiTokens.surfaceLight,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CameraUiTokens.radius24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
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

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Glass Surface
                CameraGlassSurface(
                  role: CameraGlassRole.sheetHeader,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(CameraUiTokens.radius24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(
                              top: CameraUiTokens.spacing8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                                CameraUiTokens.radiusFull),
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
                            CameraGlassIconButton(
                              key: const ValueKey('sheet_close_button'),
                              icon: Icons.close,
                              label: 'camera.close'.tr(),
                              embedded: true,
                              onPressed: () => Navigator.of(context).pop(),
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
                              CameraGlassIconButton(
                                key: const ValueKey('sheet_favorite_button'),
                                iconSize: CameraUiTokens.controlIconSize,
                                icon:
                                    isFavorite ? Icons.star : Icons.star_border,
                                label: isFavorite
                                    ? 'camera.unfavorite'.tr()
                                    : 'camera.favorite'.tr(),
                                selected: isFavorite,
                                embedded: true,
                                onPressed: () {
                                  widget.favorites
                                      .setSaved(camera, !isFavorite);
                                },
                              ),
                          ],
                        ),
                      ),

                      // District/address subtitle if available
                      if (camera?.district != null || camera?.address != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            CameraUiTokens.spacing16,
                            0,
                            CameraUiTokens.spacing16,
                            CameraUiTokens.spacing8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              camera?.address ?? camera?.district ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: CameraUiTokens.primaryTeal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Media & details scrollable body (outside glass)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: CameraUiTokens.spacing8),

                        // Media area: snapshot polling by default; a live HLS
                        // player when the camera supports it and the user
                        // switches to "Trực tiếp" (T14). A live failure falls
                        // back to the snapshot with a note.
                        Padding(
                          padding:
                              const EdgeInsets.all(CameraUiTokens.spacing16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (camera != null && camera.canLive) ...[
                                SegmentedButton<bool>(
                                  key: const ValueKey('live_mode_toggle'),
                                  segments: [
                                    ButtonSegment(
                                      value: false,
                                      icon: const Icon(Icons.image_outlined),
                                      label:
                                          Text('camera.snapshot_static'.tr()),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      icon: const Icon(Icons.live_tv_outlined),
                                      label: Text('camera.live'.tr()),
                                    ),
                                  ],
                                  selected: {_liveMode},
                                  onSelectionChanged: (selection) {
                                    setState(() => _liveMode = selection.first);
                                  },
                                ),
                                const SizedBox(
                                    height: CameraUiTokens.spacing12),
                              ],
                              if (_liveFailed) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: CameraUiTokens.errorRed,
                                    ),
                                    const SizedBox(
                                        width: CameraUiTokens.spacing4),
                                    Expanded(
                                      child: Text(
                                        'camera.live_unavailable'.tr(),
                                        style: const TextStyle(
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

                        // Camera traffic map card — rendered when the
                        // camera has location coordinates.
                        if (camera != null && camera.hasLocation)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              CameraUiTokens.spacing16,
                              0,
                              CameraUiTokens.spacing16,
                              CameraUiTokens.spacing16,
                            ),
                            child: CameraTrafficMapCard(
                              key: ValueKey('traffic_map_${camera.id}'),
                              camera: camera,
                              active: _routeIsCurrent &&
                                  _appIsForeground &&
                                  !_mapCovered,
                              mapBuilder: widget.mapBuilder,
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
                              label: Text('camera.directions'.tr()),
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
                            snapshotFetchedAt: state.currentFrame?.fetchedAt,
                            isStale: state.isStale,
                            onDirectionsTap: camera.hasLocation
                                ? () => openCameraDirections(camera)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
            Text('camera.snapshot_load_failed'.tr()),
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
      onTap: _openImageViewer,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'camera.stale_image'.tr(),
                          style: const TextStyle(
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
