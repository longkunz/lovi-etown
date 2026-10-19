import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/fixture_camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_state.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_favorites_section.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_filters.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_tile.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/thumbnail_scheduler.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart' hide State;

class _NoOpFavoritesRepository implements FavoritesRepository {
  const _NoOpFavoritesRepository();

  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield const [];
  }

  @override
  FutureEither<void> load() async => const Right(null);

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async => const Right(null);

  @override
  FutureEither<void> resetCorruptData() async => const Right(null);
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    this.catalogCubit,
    this.cameraRepository,
    this.favoritesRepository,
    this.cache,
    this.thumbnailScheduler,
    this.onSelectCamera,
    this.isDemoMode = false,
    super.key,
  });

  final CameraCatalogCubit? catalogCubit;
  final CameraRepository? cameraRepository;
  final FavoritesRepository? favoritesRepository;
  final SnapshotMemoryCache? cache;
  final ThumbnailScheduler? thumbnailScheduler;
  final ValueChanged<Camera>? onSelectCamera;
  final bool isDemoMode;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late final CameraCatalogCubit _catalogCubit;
  late final CameraPreviewCubit _previewCubit;
  late final FavoritesRepository _favoritesRepository;
  late final SnapshotMemoryCache _cache;
  late final ThumbnailScheduler _thumbnailScheduler;
  late final bool _ownsCubit;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<FavoriteCamera>>? _favSub;
  Set<String> _favoriteIds = {};
  bool _isCorruptFavorites = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _favoritesRepository =
        widget.favoritesRepository ?? const _NoOpFavoritesRepository();
    final repo = widget.cameraRepository ?? FixtureCameraRepository();
    _cache = widget.cache ?? SnapshotMemoryCache();
    _previewCubit = CameraPreviewCubit(repository: repo, cache: _cache);
    _thumbnailScheduler = widget.thumbnailScheduler ??
        ThumbnailScheduler(repository: repo, cache: _cache);

    if (widget.catalogCubit != null) {
      _catalogCubit = widget.catalogCubit!;
      _ownsCubit = false;
    } else {
      _catalogCubit = CameraCatalogCubit(repository: repo);
      _ownsCubit = true;
    }

    _cache.addListener(_onCacheChanged);
    _catalogCubit.start();
    _loadFavorites();
    _favSub = _favoritesRepository.watch().listen((favs) {
      if (mounted) {
        setState(() {
          _favoriteIds = favs.map((f) => f.id).toSet();
        });
      }
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    _thumbnailScheduler.setForeground(isForeground);
    _previewCubit.setForeground(isForeground);
    if (isForeground) {
      _updateThumbnailWindow();
    }
  }

  Future<void> _loadFavorites() async {
    final res = await _favoritesRepository.load();
    res.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isCorruptFavorites = failure.message.contains('hỏng') ||
                failure.message.contains('corrupt') ||
                failure.message.contains('không hợp lệ');
          });
        }
      },
      (_) {},
    );
  }

  Future<void> _handleResetCorruptData() async {
    final res = await _favoritesRepository.resetCorruptData();
    res.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể đặt lại: ${failure.message}'),
              backgroundColor: CameraUiTokens.errorRed,
            ),
          );
        }
      },
      (_) {
        if (mounted) {
          setState(() {
            _isCorruptFavorites = false;
          });
        }
      },
    );
  }

  void _onCacheChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 600) {
      _catalogCubit.loadNextPage();
    }
    _updateThumbnailWindow();
  }

  void _updateThumbnailWindow() {
    if (!mounted) return;
    final items = _catalogCubit.state.items;
    if (items.isEmpty) return;

    final double itemHeight;
    final int crossAxis;
    switch (_catalogCubit.state.viewMode) {
      case CameraViewMode.card:
        itemHeight = 220;
        crossAxis = 1;
      case CameraViewMode.grid:
        itemHeight = 160;
        crossAxis = MediaQuery.of(context).size.width >= 600 ? 3 : 2;
      case CameraViewMode.list:
        itemHeight = 88;
        crossAxis = 1;
    }

    final double scrollY =
        _scrollController.hasClients ? _scrollController.offset : 0;
    final double viewportHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : 800;

    final int firstVisibleRow = (scrollY / itemHeight)
        .floor()
        .clamp(0, (items.length / crossAxis).ceil());
    final int lastVisibleRow = ((scrollY + viewportHeight) / itemHeight)
        .ceil()
        .clamp(0, (items.length / crossAxis).ceil());

    final int firstVisible =
        (firstVisibleRow * crossAxis).clamp(0, items.length);
    final int lastVisible =
        (lastVisibleRow * crossAxis).clamp(0, items.length);

    final visibleIds = <String>{};
    for (int i = firstVisible; i < lastVisible; i++) {
      visibleIds.add(items[i].id);
    }

    final prefetchIds = <String>{};
    final prefetchEnd = (lastVisible + 6).clamp(0, items.length);
    for (int i = lastVisible; i < prefetchEnd; i++) {
      prefetchIds.add(items[i].id);
    }

    final endpoints = <String, String>{};
    for (final cam in items) {
      final ep = cam.thumbnailEndpoint ?? cam.snapshotEndpoint;
      if (ep != null && ep.isNotEmpty) {
        endpoints[cam.id] = ep;
      }
    }

    _thumbnailScheduler.updateWindow(
      visible: visibleIds,
      prefetch: prefetchIds,
      endpoints: endpoints,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _favSub?.cancel();
    _cache.removeListener(_onCacheChanged);
    _thumbnailScheduler.dispose();
    _previewCubit.close();
    if (_ownsCubit) {
      _catalogCubit.close();
    }
    super.dispose();
  }

  void _handleSelectCamera(Camera camera) {
    _catalogCubit.setAnchorCameraId(camera.id);
    _thumbnailScheduler.setPreviewCamera(camera.id);
    if (widget.onSelectCamera != null) {
      widget.onSelectCamera!(camera);
    } else {
      showCameraSnapshotSheet(
        context,
        cameraId: camera.id,
        preview: _previewCubit,
        favorites: _favoritesRepository,
      ).whenComplete(() {
        _thumbnailScheduler.setPreviewCamera(null);
        _updateThumbnailWindow();
      });
    }
  }

  Future<void> _handleToggleFavorite(Camera camera) async {
    final isFav = _favoriteIds.contains(camera.id);
    final res = await _favoritesRepository.setSaved(camera, !isFav);
    res.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi cập nhật Quan tâm: ${failure.message}'),
              backgroundColor: CameraUiTokens.errorRed,
            ),
          );
        }
      },
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _catalogCubit,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: const AdaptiveGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: 0),
            settings: LiquidGlassSettings(
              blur: CameraUiTokens.glassBlur,
              thickness: 10,
              glassColor: Color(0x1A00796B),
            ),
            child: SizedBox.expand(),
          ),
          title: Text(
            'camera.title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (widget.isDemoMode)
              Padding(
                padding: const EdgeInsets.only(right: CameraUiTokens.spacing16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraUiTokens.spacing8,
                      vertical: CameraUiTokens.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: CameraUiTokens.badgeDemoBg,
                      borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
                      border: Border.all(color: CameraUiTokens.badgeDemoText.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'shared.demo_mode_badge'.tr(),
                      style: const TextStyle(
                        color: CameraUiTokens.badgeDemoText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: BlocConsumer<CameraCatalogCubit, CameraCatalogState>(
          listener: (context, state) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateThumbnailWindow();
            });
          },
          builder: (context, state) {
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Filters
                SliverToBoxAdapter(
                  child: CameraFilters(
                    districts: state.districts,
                    selectedDistrict: state.district,
                    onDistrictChanged: _catalogCubit.setDistrict,
                    query: state.query,
                    onQueryChanged: _catalogCubit.setQuery,
                    viewMode: state.viewMode,
                    onViewModeChanged: _catalogCubit.setViewMode,
                    validationMessage: state.queryValidationMessage,
                  ),
                ),

                // Corrupt favorites warning & CTA
                if (_isCorruptFavorites)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: CameraUiTokens.spacing16,
                        vertical: CameraUiTokens.spacing8,
                      ),
                      padding: const EdgeInsets.all(CameraUiTokens.spacing12),
                      decoration: BoxDecoration(
                        color: CameraUiTokens.errorRed.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(CameraUiTokens.radius8),
                        border: Border.all(color: CameraUiTokens.errorRed),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: CameraUiTokens.errorRed),
                          const SizedBox(width: CameraUiTokens.spacing8),
                          const Expanded(
                            child: Text(
                              'Dữ liệu quan tâm bị hỏng.',
                              style: TextStyle(
                                color: CameraUiTokens.errorRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _handleResetCorruptData,
                            child: const Text('Đặt lại'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Inline Favorites Section
                SliverToBoxAdapter(
                  child: _buildFavoritesSection(context),
                ),

                // Feed Content
                _buildCatalogFeed(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFavoritesSection(BuildContext context) {
    return StreamBuilder<List<FavoriteCamera>>(
      stream: _favoritesRepository.watch(),
      initialData: const [],
      builder: (context, snapshot) {
        final favorites = snapshot.data ?? const [];
        return CameraFavoritesSection(
          favorites: favorites,
          onSelectCamera: _handleSelectCamera,
          onToggleFavorite: _handleToggleFavorite,
        );
      },
    );
  }

  Widget _buildCatalogFeed(BuildContext context, CameraCatalogState state) {
    if (state.catalogState.isLoading && state.items.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.catalogState.isFailure && state.items.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: CameraUiTokens.errorRed),
              const SizedBox(height: CameraUiTokens.spacing8),
              const Text('Không thể tải danh sách camera'),
              const SizedBox(height: CameraUiTokens.spacing12),
              ElevatedButton(
                onPressed: _catalogCubit.retry,
                child: Text('shared.retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('Không tìm thấy camera phù hợp'),
        ),
      );
    }

    Widget contentSliver;
    final isLargeScreen = MediaQuery.of(context).size.width >= 600;

    switch (state.viewMode) {
      case CameraViewMode.card:
        contentSliver = SliverList.builder(
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final cam = state.items[index];
            return CameraTile(
              key: ValueKey('cam_${cam.id}'),
              camera: cam,
              viewMode: CameraViewMode.card,
              isFavorite: _favoriteIds.contains(cam.id),
              thumbnailBytes: _cache.get(cam.id)?.bytes,
              onTap: () => _handleSelectCamera(cam),
              onToggleFavorite: () => _handleToggleFavorite(cam),
            );
          },
        );
      case CameraViewMode.grid:
        final crossAxisCount = isLargeScreen ? 3 : 2;
        contentSliver = SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: CameraUiTokens.spacing16,
            vertical: CameraUiTokens.spacing8,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: CameraUiTokens.spacing8,
              crossAxisSpacing: CameraUiTokens.spacing8,
              childAspectRatio: 0.9,
            ),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final cam = state.items[index];
              return CameraTile(
                key: ValueKey('cam_${cam.id}'),
                camera: cam,
                viewMode: CameraViewMode.grid,
                isFavorite: _favoriteIds.contains(cam.id),
                thumbnailBytes: _cache.get(cam.id)?.bytes,
                onTap: () => _handleSelectCamera(cam),
                onToggleFavorite: () => _handleToggleFavorite(cam),
              );
            },
          ),
        );
      case CameraViewMode.list:
        contentSliver = SliverList.builder(
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final cam = state.items[index];
            return CameraTile(
              key: ValueKey('cam_${cam.id}'),
              camera: cam,
              viewMode: CameraViewMode.list,
              isFavorite: _favoriteIds.contains(cam.id),
              thumbnailBytes: _cache.get(cam.id)?.bytes,
              onTap: () => _handleSelectCamera(cam),
              onToggleFavorite: () => _handleToggleFavorite(cam),
            );
          },
        );
    }

    return SliverMainAxisGroup(
      slivers: [
        contentSliver,
        if (state.paginationState.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(CameraUiTokens.spacing16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (state.paginationState.isFailure)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(CameraUiTokens.spacing16),
              child: Center(
                child: TextButton.icon(
                  onPressed: _catalogCubit.loadNextPage,
                  icon: const Icon(Icons.refresh),
                  label: Text('shared.retry'.tr()),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
