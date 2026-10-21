import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/thumbnail_scheduler.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Picks the favorites shown in the multi-camera grid (T12): catalog-known
/// favorites in their saved order, capped at [max] (default 6).
List<FavoriteCamera> selectGridFavorites(
  List<FavoriteCamera> favorites, {
  int max = 6,
}) {
  return favorites
      .where((f) => !f.isMissingFromCatalog)
      .take(max)
      .toList(growable: false);
}

/// Multi-camera grid (T12): 4–6 favorite cameras side by side, refreshed on
/// the snapshot cadence via the same ThumbnailScheduler/SnapshotMemoryCache
/// machinery as the catalog. Tapping a cell opens the usual snapshot sheet.
/// Refreshing stops when the screen is closed or the app is backgrounded.
class MultiCameraScreen extends StatefulWidget {
  const MultiCameraScreen({
    required this.favorites,
    required this.repository,
    required this.favoritesRepository,
    this.refreshInterval = const Duration(seconds: 20),
    super.key,
  });

  final List<FavoriteCamera> favorites;
  final CameraRepository repository;
  final FavoritesRepository favoritesRepository;
  final Duration refreshInterval;

  @override
  State<MultiCameraScreen> createState() => _MultiCameraScreenState();
}

class _MultiCameraScreenState extends State<MultiCameraScreen>
    with WidgetsBindingObserver {
  late final SnapshotMemoryCache _cache;
  late final ThumbnailScheduler _scheduler;
  late final CameraPreviewCubit _previewCubit;
  final Map<String, Camera> _cameras = {};
  final Set<String> _failed = {};
  Timer? _refreshTimer;
  bool _disposed = false;

  List<FavoriteCamera> get _selected => selectGridFavorites(widget.favorites);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cache = SnapshotMemoryCache();
    _scheduler = ThumbnailScheduler(repository: widget.repository, cache: _cache);
    _previewCubit = CameraPreviewCubit(repository: widget.repository, cache: _cache);
    _cache.addListener(_onCacheChanged);
    _resolveCameras();
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) => _refresh());
  }

  Future<void> _resolveCameras() async {
    for (final favorite in _selected) {
      final result = await widget.repository.detail(favorite.id);
      if (_disposed) return;
      result.fold(
        (_) => setState(() => _failed.add(favorite.id)),
        (camera) {
          setState(() => _cameras[camera.id] = camera);
          _requestWindow();
        },
      );
    }
  }

  void _requestWindow() {
    final endpoints = <String, String>{};
    for (final camera in _cameras.values) {
      final endpoint = camera.snapshotEndpoint;
      if (endpoint != null && endpoint.isNotEmpty) {
        endpoints[camera.id] = endpoint;
      }
    }
    _scheduler.updateWindow(
      visible: endpoints.keys.toSet(),
      prefetch: const {},
      endpoints: endpoints,
    );
  }

  void _refresh() {
    if (_disposed) return;
    // Evicting the cached frames makes the scheduler fetch fresh ones.
    for (final id in _cameras.keys) {
      _cache.remove(id);
    }
    _requestWindow();
  }

  void _onCacheChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    _scheduler.setForeground(isForeground);
    _previewCubit.setForeground(isForeground);
    if (isForeground) _refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _cache.removeListener(_onCacheChanged);
    _scheduler.dispose();
    _previewCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lưới camera'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: selected.isEmpty
          ? const Center(child: Text('Chưa có camera Quan tâm khả dụng'))
          : GridView.builder(
              padding: const EdgeInsets.all(CameraUiTokens.spacing8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: CameraUiTokens.spacing8,
                mainAxisSpacing: CameraUiTokens.spacing8,
                childAspectRatio: 4 / 3,
              ),
              itemCount: selected.length,
              itemBuilder: (context, index) {
                final favorite = selected[index];
                return _GridCell(
                  key: ValueKey('grid_cell_${favorite.id}'),
                  favorite: favorite,
                  camera: _cameras[favorite.id],
                  failed: _failed.contains(favorite.id),
                  frame: _cache.get(favorite.id),
                  onTap: _cameras.containsKey(favorite.id)
                      ? () => showCameraSnapshotSheet(
                            context,
                            cameraId: favorite.id,
                            preview: _previewCubit,
                            favorites: widget.favoritesRepository,
                          )
                      : null,
                );
              },
            ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.favorite,
    required this.camera,
    required this.failed,
    required this.frame,
    required this.onTap,
    super.key,
  });

  final FavoriteCamera favorite;
  final Camera? camera;
  final bool failed;
  final SnapshotFrame? frame;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = frame?.bytes;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: bytes != null && bytes.isNotEmpty
                  ? Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.videocam_outlined,
                        color: CameraUiTokens.primaryTeal,
                        size: 36,
                      ),
                    )
                  : Icon(
                      failed ? Icons.videocam_off_outlined : Icons.videocam_outlined,
                      color: CameraUiTokens.primaryTeal,
                      size: 36,
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CameraUiTokens.spacing8,
                  vertical: CameraUiTokens.spacing4,
                ),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  failed ? '${favorite.name} (không tải được)' : favorite.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
