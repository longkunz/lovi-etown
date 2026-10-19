import 'package:equatable/equatable.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/utils/async_state.dart';
import 'package:flutter_starter/src/utils/failure.dart';

class CameraCatalogState extends Equatable {
  const CameraCatalogState({
    this.catalogState = const RequestInitial(),
    this.paginationState = const RequestInitial(),
    this.items = const [],
    this.districts = const [],
    this.query = '',
    this.district,
    this.queryValidationMessage,
    this.viewMode = CameraViewMode.card,
    this.gridDensity = GridDensity.comfortable,
    this.anchorCameraId,
    this.generation = 0,
    this.catalogVersion,
    this.nextOffset = 0,
    this.total = 0,
    this.hasMore = false,
  });

  final RequestState<CatalogPage> catalogState;
  final RequestState<void> paginationState;
  final List<Camera> items;
  final List<DistrictOption> districts;
  final String query;
  final String? district;
  final String? queryValidationMessage;
  final CameraViewMode viewMode;
  final GridDensity gridDensity;
  final String? anchorCameraId;
  final int generation;
  final String? catalogVersion;
  final int nextOffset;
  final int total;
  final bool hasMore;

  /// T06-D4: the backend rejected this build's reader key (401/403). The
  /// only remedy is installing a newer app build, so the screen must show
  /// the dedicated update-required view instead of a retryable error.
  bool get isUpdateRequired {
    final state = catalogState;
    if (state is! RequestFailure<CatalogPage>) return false;
    final failure = state.failure;
    return failure is ApiFailure &&
        (failure.statusCode == 401 || failure.statusCode == 403);
  }

  CameraCatalogState copyWith({
    RequestState<CatalogPage>? catalogState,
    RequestState<void>? paginationState,
    List<Camera>? items,
    List<DistrictOption>? districts,
    String? query,
    String? district,
    bool clearDistrict = false,
    String? queryValidationMessage,
    bool clearValidation = false,
    CameraViewMode? viewMode,
    GridDensity? gridDensity,
    String? anchorCameraId,
    int? generation,
    String? catalogVersion,
    int? nextOffset,
    int? total,
    bool? hasMore,
  }) {
    return CameraCatalogState(
      catalogState: catalogState ?? this.catalogState,
      paginationState: paginationState ?? this.paginationState,
      items: items ?? this.items,
      districts: districts ?? this.districts,
      query: query ?? this.query,
      district: clearDistrict ? null : (district ?? this.district),
      queryValidationMessage: clearValidation
          ? null
          : (queryValidationMessage ?? this.queryValidationMessage),
      viewMode: viewMode ?? this.viewMode,
      gridDensity: gridDensity ?? this.gridDensity,
      anchorCameraId: anchorCameraId ?? this.anchorCameraId,
      generation: generation ?? this.generation,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      nextOffset: nextOffset ?? this.nextOffset,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [
        catalogState,
        paginationState,
        items,
        districts,
        query,
        district,
        queryValidationMessage,
        viewMode,
        gridDensity,
        anchorCameraId,
        generation,
        catalogVersion,
        nextOffset,
        total,
        hasMore,
      ];
}
