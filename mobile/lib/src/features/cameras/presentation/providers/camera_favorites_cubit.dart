import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_favorites_state.dart';

class CameraFavoritesCubit extends Cubit<CameraFavoritesState> {
  CameraFavoritesCubit({required FavoritesRepository favoritesRepository})
      : _favoritesRepository = favoritesRepository,
        super(const CameraFavoritesState()) {
    _subscription = _favoritesRepository.watch().listen((list) {
      emit(state.copyWith(favorites: list));
    });
  }

  final FavoritesRepository _favoritesRepository;
  StreamSubscription<List<FavoriteCamera>>? _subscription;

  static const int _maxConcurrency = 4;

  Future<void> init() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final loadResult = await _favoritesRepository.load();

    await loadResult.fold(
      (failure) async {
        emit(state.copyWith(
          isLoading: false,
          isCorrupt: true,
          error: failure,
        ));
      },
      (_) async {
        final current = await _favoritesRepository.watch().first;
        emit(state.copyWith(
          favorites: current,
          isLoading: false,
          isCorrupt: false,
          clearError: true,
        ));
      },
    );
  }

  Future<void> toggle(Camera camera) async {
    final isFav = state.favorites.any((f) => f.id == camera.id);
    final result = await _favoritesRepository.setSaved(camera, !isFav);
    result.fold(
      (failure) {
        emit(state.copyWith(error: failure));
      },
      (_) {},
    );
  }

  Future<void> revalidate(CameraRepository cameraRepository) async {
    final items = List<FavoriteCamera>.from(state.favorites);
    if (items.isEmpty) return;

    final updatedList = List<FavoriteCamera>.from(items);

    // Process in batches of max 4 concurrent requests
    for (var i = 0; i < items.length; i += _maxConcurrency) {
      final end = (i + _maxConcurrency < items.length) ? i + _maxConcurrency : items.length;
      final batch = items.sublist(i, end);

      await Future.wait(batch.map((fav) async {
        final result = await cameraRepository.detail(fav.id);
        result.fold(
          (failure) {
            if (failure.message.contains('404')) {
              final idx = updatedList.indexWhere((f) => f.id == fav.id);
              if (idx >= 0) {
                updatedList[idx] = updatedList[idx].copyWith(isMissingFromCatalog: true);
              }
            }
            // On network failure, retain last known metadata
          },
          (freshCamera) {
            final idx = updatedList.indexWhere((f) => f.id == fav.id);
            if (idx >= 0) {
              updatedList[idx] = updatedList[idx].copyWith(
                name: freshCamera.name,
                district: freshCamera.district,
                address: freshCamera.address,
                isMissingFromCatalog: false,
              );
            }
          },
        );
      }));
    }

    emit(state.copyWith(favorites: updatedList));
  }

  Future<void> resetCorruptData() async {
    emit(state.copyWith(isLoading: true));
    final result = await _favoritesRepository.resetCorruptData();
    result.fold(
      (failure) {
        emit(state.copyWith(isLoading: false, error: failure));
      },
      (_) {
        emit(state.copyWith(
          isLoading: false,
          isCorrupt: false,
          clearError: true,
          favorites: const [],
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
