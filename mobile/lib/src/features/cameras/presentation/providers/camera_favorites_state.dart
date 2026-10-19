import 'package:equatable/equatable.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/utils/failure.dart';

class CameraFavoritesState extends Equatable {
  const CameraFavoritesState({
    this.favorites = const [],
    this.isCorrupt = false,
    this.error,
    this.isLoading = false,
  });

  final List<FavoriteCamera> favorites;
  final bool isCorrupt;
  final Failure? error;
  final bool isLoading;

  CameraFavoritesState copyWith({
    List<FavoriteCamera>? favorites,
    bool? isCorrupt,
    Failure? error,
    bool clearError = false,
    bool? isLoading,
  }) {
    return CameraFavoritesState(
      favorites: favorites ?? this.favorites,
      isCorrupt: isCorrupt ?? this.isCorrupt,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [favorites, isCorrupt, error, isLoading];
}
