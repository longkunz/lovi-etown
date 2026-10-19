import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_catalog_state.dart';
import 'package:flutter_starter/src/utils/async_state.dart';

class CameraCatalogCubit extends Cubit<CameraCatalogState> {
  CameraCatalogCubit({required CameraRepository repository})
      : _repository = repository,
        super(const CameraCatalogState());

  final CameraRepository _repository;
  Timer? _debounceTimer;
  CancelToken? _currentCancelToken;

  static const int _pageSize = 50;
  static const int _maxOffset = 10000;

  Future<void> start() async {
    emit(state.copyWith(catalogState: const RequestLoading()));

    // Load districts first or in parallel
    final districtsResult = await _repository.districts();
    List<DistrictOption> districts = state.districts;
    districtsResult.fold(
      (failure) {},
      (list) {
        districts = list;
      },
    );

    emit(state.copyWith(districts: districts));
    await _loadPage(offset: 0, reset: true);
  }

  void setQuery(String rawQuery) {
    final trimmed = rawQuery.trim();
    _debounceTimer?.cancel();
    _currentCancelToken?.cancel('Query changed');
    _currentCancelToken = null;

    final nextGen = state.generation + 1;

    if (trimmed.length == 1) {
      emit(state.copyWith(
        query: trimmed,
        queryValidationMessage: 'Vui lòng nhập tối thiểu 2 ký tự',
        generation: nextGen,
      ));
      return;
    }

    emit(state.copyWith(
      query: trimmed,
      clearValidation: true,
      generation: nextGen,
    ));

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _loadPage(offset: 0, reset: true, generation: nextGen);
    });
  }

  void setDistrict(String? district) {
    if (state.district == district) return;
    _debounceTimer?.cancel();
    final nextGen = state.generation + 1;
    emit(state.copyWith(
      district: district,
      clearDistrict: district == null,
      generation: nextGen,
    ));
    _loadPage(offset: 0, reset: true, generation: nextGen);
  }

  void setViewMode(CameraViewMode mode) {
    emit(state.copyWith(viewMode: mode));
  }

  void setGridDensity(GridDensity density) {
    emit(state.copyWith(gridDensity: density));
  }

  void setAnchorCameraId(String? id) {
    emit(state.copyWith(anchorCameraId: id));
  }

  Future<void> retry() async {
    if (state.items.isEmpty) {
      await start();
    } else {
      await loadNextPage();
    }
  }

  Future<void> loadNextPage() async {
    if (!state.hasMore || state.paginationState.isLoading) {
      return;
    }
    if (state.nextOffset >= _maxOffset) {
      return;
    }
    await _loadPage(offset: state.nextOffset, reset: false, generation: state.generation);
  }

  Future<void> _loadPage({
    required int offset,
    required bool reset,
    int? generation,
  }) async {
    final gen = generation ?? state.generation;

    if (reset) {
      _currentCancelToken?.cancel();
      _currentCancelToken = CancelToken();
      emit(state.copyWith(catalogState: const RequestLoading()));
    } else {
      emit(state.copyWith(paginationState: const RequestLoading()));
    }

    final query = state.query.length >= 2 ? state.query : null;
    final district = state.district;

    final result = await _repository.list(
      query: query,
      district: district,
      limit: _pageSize,
      offset: offset,
      cancelToken: _currentCancelToken,
    );

    // Stale check
    if (gen != state.generation) {
      return;
    }

    result.fold(
      (failure) {
        if (reset) {
          emit(state.copyWith(catalogState: RequestFailure(failure)));
        } else {
          emit(state.copyWith(paginationState: RequestFailure(failure)));
        }
      },
      (page) async {
        if (!reset &&
            state.catalogVersion != null &&
            state.catalogVersion != page.catalogVersion) {
          await _loadPage(offset: 0, reset: true, generation: gen);
          return;
        }

        final List<Camera> updatedItems;
        if (reset) {
          updatedItems = page.items;
        } else {
          final existingIds = state.items.map((c) => c.id).toSet();
          final newItems =
              page.items.where((c) => !existingIds.contains(c.id)).toList();
          updatedItems = [...state.items, ...newItems];
        }

        final nextOffset = page.offset + page.items.length;
        final hasMore =
            nextOffset < page.total && page.items.isNotEmpty && nextOffset < _maxOffset;

        emit(state.copyWith(
          catalogState: RequestSuccess(page),
          paginationState: const RequestInitial(),
          items: updatedItems,
          catalogVersion: page.catalogVersion,
          nextOffset: nextOffset,
          total: page.total,
          hasMore: hasMore,
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _currentCancelToken?.cancel();
    return super.close();
  }
}
