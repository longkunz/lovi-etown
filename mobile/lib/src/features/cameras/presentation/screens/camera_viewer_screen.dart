import 'package:go_router/go_router.dart';
import 'package:flutter_starter/src/routing/app_routes.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_state.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_directions.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_live_player.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_refresh_countdown.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_traffic_map_card.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/traffic_brief_card.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Full-screen viewer for a single camera, mirroring the reference
/// `camera_view` structure: a media area with a Trực tiếp / Ảnh mode
/// switcher, a full-screen media view, camera info, actions, the traffic
/// brief and a related-cameras row.
///
/// The viewer owns its [CameraPreviewCubit]: it opens the camera on init
/// and closes the cubit on dispose, so snapshot polling (12s cadence,
/// last-good frame + stale handling) follows the screen lifecycle.
class CameraViewerScreen extends StatefulWidget {
  const CameraViewerScreen({
    required this.cameraId,
    required this.repository,
    required this.favoritesRepository,
    this.onOpenMultiCamera,
    this.mapBuilder,
    super.key,
  });

  final String cameraId;
  final CameraRepository repository;
  final FavoritesRepository favoritesRepository;

  /// Opens the multi-camera grid; when null the shortcut is hidden
  /// (e.g. when the viewer itself was opened from the grid).
  final VoidCallback? onOpenMultiCamera;

  /// Optional custom map builder for testing (T18).
  final Widget Function(BuildContext, CameraTrafficMapConfig)? mapBuilder;

  @override
  State<CameraViewerScreen> createState() => _CameraViewerScreenState();
}

class _CameraViewerScreenState extends State<CameraViewerScreen>
    with WidgetsBindingObserver {
  late final CameraPreviewCubit _previewCubit;
  StreamSubscription<List<FavoriteCamera>>? _favSub;
  Set<String> _favoriteIds = {};
  List<Camera> _related = const [];

  /// Mode chosen by the user; null means "auto" — Live when the camera
  /// can stream, Ảnh otherwise.
  bool? _liveOverride;
  bool _liveFailed = false;
  bool _routeIsCurrent = true;
  bool _snapshotFullscreenOpen = false;
  bool _mapCovered = false;
  bool _appIsForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsForeground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _previewCubit = CameraPreviewCubit(
      repository: widget.repository,
      cache: SnapshotMemoryCache(),
    );
    _previewCubit.setForeground(_appIsForeground);
    _previewCubit.open(widget.cameraId);
    _favSub = widget.favoritesRepository.watch().listen((favs) {
      if (mounted) {
        setState(() {
          _favoriteIds = favs.map((f) => f.id).toSet();
        });
      }
    });
    _loadRelated();
  }

  Future<void> _loadRelated() async {
    final result = await widget.repository.related(widget.cameraId);
    if (!mounted) return;
    result.fold(
      (_) {},
      (items) => setState(() {
        _related =
            items.where((c) => c.id != widget.cameraId).toList(growable: false);
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _updatePreviewActivity();
  }

  void _updatePreviewActivity() {
    _previewCubit.setForeground(
      _appIsForeground && (_routeIsCurrent || _snapshotFullscreenOpen),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _appIsForeground = state == AppLifecycleState.resumed;
    });
    _updatePreviewActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _favSub?.cancel();
    _previewCubit.close();
    super.dispose();
  }

  void _handleLiveUnavailable() {
    if (!mounted) return;
    setState(() {
      _liveFailed = true;
      _liveOverride = false;
    });
  }

  Future<void> _openCamera(Camera camera) async {
    setState(() => _mapCovered = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CameraViewerScreen(
            cameraId: camera.id,
            repository: widget.repository,
            favoritesRepository: widget.favoritesRepository,
            mapBuilder: widget.mapBuilder,
            onOpenMultiCamera: widget.onOpenMultiCamera,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _mapCovered = false);
    }
  }

  Future<void> _openFullScreen(Camera camera,
      {required bool liveSelected}) async {
    final showLive = liveSelected && camera.canLive && !_liveFailed;
    setState(() {
      _snapshotFullscreenOpen = !showLive;
      _mapCovered = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.97),
          pageBuilder: (routeContext, _, __) {
            final media = showLive
                ? CameraLivePlayer(
                    key: const ValueKey('viewer_fullscreen_live_player'),
                    streamUrl: camera.streamUrl!,
                    onUnavailable: () {
                      Navigator.of(routeContext).pop();
                      _handleLiveUnavailable();
                    },
                  )
                : BlocBuilder<CameraPreviewCubit, CameraPreviewState>(
                    bloc: _previewCubit,
                    builder: (_, state) => _SnapshotView(
                      state: state,
                      onRetry: _previewCubit.retry,
                      fullScreen: true,
                    ),
                  );
            return _FullScreenMediaPage(cameraName: camera.name, child: media);
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _snapshotFullscreenOpen = false;
          _mapCovered = false;
        });
        _updatePreviewActivity();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CameraUiTokens.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const CameraGlassSurface(
          role: CameraGlassRole.header,
          brightness: Brightness.dark,
          borderRadius: BorderRadius.zero,
          child: SizedBox.expand(),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: BackButton(onPressed: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            GoRouter.maybeOf(context)?.go(AppRoutes.map);
          }
        }),
        title: BlocBuilder<CameraPreviewCubit, CameraPreviewState>(
          bloc: _previewCubit,
          buildWhen: (prev, curr) => prev.camera?.name != curr.camera?.name,
          builder: (context, state) => Text(
            state.camera?.name ?? 'Camera',
            style: const TextStyle(color: Colors.white, fontSize: 17),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: BlocBuilder<CameraPreviewCubit, CameraPreviewState>(
        bloc: _previewCubit,
        builder: (context, state) {
          final camera = state.camera;
          if (camera == null) {
            if (state.cameraState.isFailure) {
              return _buildLoadFailure(context);
            }
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final isFavorite = _favoriteIds.contains(camera.id);
          final liveSelected = _liveOverride ?? camera.canLive;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMediaArea(context, state, liveSelected),
                const SizedBox(height: CameraUiTokens.spacing12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CameraUiTokens.spacing16,
                  ),
                  child: SegmentedButton<bool>(
                    key: const ValueKey('viewer_mode_switcher'),
                    style: SegmentedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      selectedForegroundColor: Colors.white,
                      selectedBackgroundColor: CameraUiTokens.primaryTeal,
                    ),
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.live_tv_outlined),
                        label: Text('camera.live'.tr()),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.image_outlined),
                        label: Text('camera.snapshot'.tr()),
                      ),
                    ],
                    selected: {liveSelected},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _liveOverride = selection.first;
                        if (selection.first) _liveFailed = false;
                      });
                    },
                  ),
                ),
                if (_liveFailed) ...[
                  const SizedBox(height: CameraUiTokens.spacing8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraUiTokens.spacing16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: CameraUiTokens.errorRed,
                        ),
                        const SizedBox(width: CameraUiTokens.spacing4),
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
                  ),
                ],
                if (liveSelected && !camera.canLive) ...[
                  const SizedBox(height: CameraUiTokens.spacing8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraUiTokens.spacing16,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: CameraUiTokens.spacing4),
                        Expanded(
                          child: Text(
                            'camera.no_live'.tr(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: CameraUiTokens.spacing16),
                _buildInfoSection(context, camera),
                const SizedBox(height: CameraUiTokens.spacing12),
                _buildActionRow(context, camera, isFavorite),
                if (camera.hasLocation) ...[
                  const SizedBox(height: CameraUiTokens.spacing16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraUiTokens.spacing16,
                    ),
                    child: CameraTrafficMapCard(
                      key: ValueKey('viewer_traffic_map_${camera.id}'),
                      camera: camera,
                      active:
                          _routeIsCurrent && _appIsForeground && !_mapCovered,
                      mapBuilder: widget.mapBuilder,
                    ),
                  ),
                ],
                const SizedBox(height: CameraUiTokens.spacing16),
                TrafficBriefCard(
                  key: ValueKey('traffic_brief_${camera.id}'),
                  camera: camera,
                  repository: widget.repository,
                  onSelectCamera: _openCamera,
                  snapshotFetchedAt: state.currentFrame?.fetchedAt,
                  isStale: state.isStale,
                  onDirectionsTap: camera.hasLocation
                      ? () => openCameraDirections(camera)
                      : null,
                ),
                if (_related.isNotEmpty) _buildRelatedSection(context),
                const SizedBox(height: CameraUiTokens.spacing24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadFailure(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: CameraUiTokens.errorRed),
          const SizedBox(height: CameraUiTokens.spacing8),
          Text(
            'camera.camera_info_error'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: CameraUiTokens.spacing12),
          ElevatedButton(
            onPressed: _previewCubit.retry,
            child: Text('shared.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaArea(
    BuildContext context,
    CameraPreviewState state,
    bool liveSelected,
  ) {
    final camera = state.camera!;
    final showLive = liveSelected && camera.canLive && !_liveFailed;
    return ColoredBox(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showLive)
              CameraLivePlayer(
                key: ValueKey('viewer_live_player_${camera.id}'),
                active: _routeIsCurrent && _appIsForeground,
                streamUrl: camera.streamUrl!,
                onUnavailable: _handleLiveUnavailable,
              )
            else
              _SnapshotView(
                state: state,
                onRetry: _previewCubit.retry,
                onTap: () => _openFullScreen(camera, liveSelected: false),
              ),
            Positioned(
              top: CameraUiTokens.spacing4,
              right: CameraUiTokens.spacing4,
              child: SizedBox.square(
                dimension: CameraUiTokens.minTouchTarget,
                child: IconButton(
                  key: const ValueKey('viewer_fullscreen_button'),
                  padding: EdgeInsets.zero,
                  icon: Container(
                    width: CameraUiTokens.overlayControlSize,
                    height: CameraUiTokens.overlayControlSize,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.fullscreen,
                        color: Colors.white,
                        size: CameraUiTokens.controlIconSize),
                  ),
                  tooltip: 'camera.fullscreen'.tr(),
                  onPressed: () =>
                      _openFullScreen(camera, liveSelected: liveSelected),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, Camera camera) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  camera.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (camera.canLive) ...[
                const SizedBox(width: CameraUiTokens.spacing8),
                const _LiveChip(),
              ],
            ],
          ),
          if (camera.district != null && camera.district!.isNotEmpty) ...[
            const SizedBox(height: CameraUiTokens.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CameraUiTokens.spacing8,
                vertical: CameraUiTokens.spacing4,
              ),
              decoration: BoxDecoration(
                color: CameraUiTokens.primaryTeal.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
              ),
              child: Text(
                camera.district!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: CameraUiTokens.primaryTealLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (camera.address != null && camera.address!.isNotEmpty) ...[
            const SizedBox(height: CameraUiTokens.spacing8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: CameraUiTokens.spacing4),
                Expanded(
                  child: Text(
                    camera.address!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (camera.hasLocation) ...[
            const SizedBox(height: CameraUiTokens.spacing4),
            Row(
              children: [
                const Icon(
                  Icons.my_location_outlined,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: CameraUiTokens.spacing4),
                Text(
                  '${camera.latitude!.toStringAsFixed(5)}, '
                  '${camera.longitude!.toStringAsFixed(5)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    Camera camera,
    bool isFavorite,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing16,
      ),
      child: Row(
        children: [
          if (camera.hasLocation)
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('directions_button'),
                onPressed: () => openCameraDirections(camera),
                icon: const Icon(Icons.directions),
                label: Text('camera.directions'.tr()),
              ),
            ),
          if (camera.hasLocation)
            const SizedBox(width: CameraUiTokens.spacing8),
          SizedBox(
            width: CameraUiTokens.minTouchTarget,
            height: CameraUiTokens.minTouchTarget,
            child: IconButton(
              key: const ValueKey('viewer_favorite_button'),
              tooltip: isFavorite
                  ? 'camera.unfavorite'.tr()
                  : 'camera.favorite'.tr(),
              onPressed: () {
                widget.favoritesRepository.setSaved(camera, !isFavorite);
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
          if (widget.onOpenMultiCamera != null)
            SizedBox(
              width: CameraUiTokens.minTouchTarget,
              height: CameraUiTokens.minTouchTarget,
              child: IconButton(
                key: const ValueKey('viewer_grid_button'),
                tooltip: 'camera.grid_title'.tr(),
                onPressed: widget.onOpenMultiCamera,
                icon: const Icon(
                  Icons.grid_view,
                  color: Colors.white70,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelatedSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CameraUiTokens.spacing16,
          ),
          child: Text(
            'camera.related_cameras'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: CameraUiTokens.spacing8),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: CameraUiTokens.spacing16,
            ),
            itemCount: _related.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: CameraUiTokens.spacing8),
            itemBuilder: (context, index) {
              final related = _related[index];
              return _RelatedCameraCard(
                camera: related,
                onTap: () => _openCamera(related),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Snapshot content for the viewer: last-good frame with the stale chip,
/// loading and failure handling mirroring the snapshot sheet.
class _SnapshotView extends StatelessWidget {
  const _SnapshotView({
    required this.state,
    required this.onRetry,
    this.fullScreen = false,
    this.onTap,
  });

  final CameraPreviewState state;
  final VoidCallback onRetry;
  final bool fullScreen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (state.snapshotState.isLoading && state.currentFrame == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }

    if (state.snapshotState.isFailure && state.currentFrame == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image,
                size: 40, color: CameraUiTokens.errorRed),
            const SizedBox(height: CameraUiTokens.spacing8),
            Text(
              'camera.camera_image_error'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: CameraUiTokens.spacing8),
            ElevatedButton(
              onPressed: onRetry,
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

    final content = Stack(
      fit: StackFit.expand,
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
                borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded,
                      size: 14, color: Colors.white),
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
    );

    if (fullScreen) {
      return ColoredBox(
        color: Colors.black,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(child: content),
        ),
      );
    }

    return GestureDetector(
      key: const ValueKey('viewer_snapshot_image'),
      onTap: onTap,
      child: ColoredBox(color: Colors.black, child: content),
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

/// Immersive full-screen media page: the same media content as the
/// viewer's media area, edge to edge, with a close affordance.
class _FullScreenMediaPage extends StatelessWidget {
  const _FullScreenMediaPage({
    required this.cameraName,
    required this.child,
  });

  final String cameraName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('viewer_fullscreen_page'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            CameraGlassSurface(
              role: CameraGlassRole.header,
              brightness: Brightness.dark,
              borderRadius: BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CameraUiTokens.spacing8,
                  vertical: CameraUiTokens.spacing8,
                ),
                child: Row(
                  children: [
                    CameraGlassIconButton(
                      key: const ValueKey('viewer_fullscreen_close'),
                      icon: Icons.close,
                      label: 'camera.close'.tr(),
                      embedded: true,
                      iconColor: Colors.white,
                      iconSize: 28,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: CameraUiTokens.spacing8),
                    Expanded(
                      child: Text(
                        cameraName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _RelatedCameraCard extends StatelessWidget {
  const _RelatedCameraCard({
    required this.camera,
    required this.onTap,
  });

  final Camera camera;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = camera.thumbnailEndpoint;
    return InkWell(
      key: ValueKey('related_camera_${camera.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: CameraUiTokens.surfaceDark,
          borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 72,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnail != null && thumbnail.startsWith('assets/'))
                    Image.asset(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildThumbPlaceholder(),
                    )
                  else
                    _buildThumbPlaceholder(),
                  if (camera.canLive)
                    const Positioned(
                      top: CameraUiTokens.spacing4,
                      left: CameraUiTokens.spacing4,
                      child: _LiveChip(compact: true),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(CameraUiTokens.spacing8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (camera.district != null &&
                      camera.district!.isNotEmpty) ...[
                    const SizedBox(height: CameraUiTokens.spacing2),
                    Text(
                      camera.district!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CameraUiTokens.primaryTealLight,
                        fontSize: 11,
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
    );
  }

  Widget _buildThumbPlaceholder() {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: const Icon(
        Icons.videocam_outlined,
        color: CameraUiTokens.primaryTeal,
        size: 28,
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing8,
        vertical: compact ? 2 : CameraUiTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: CameraUiTokens.errorRed,
        borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fiber_manual_record,
            size: compact ? 8 : 10,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'camera.live_upper'.tr(),
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
}
