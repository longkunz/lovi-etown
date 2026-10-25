import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/camera_map_models.dart';
import '../../domain/camera_map_repository.dart';
import '../../domain/camera_location_gateway.dart';
import '../../../../utils/failure.dart';
import 'camera_map_state.dart';

class CameraMapCubit extends Cubit<CameraMapState> {
  CameraMapCubit(
      {required CameraMapRepository repository,
      required CameraLocationGateway locationGateway})
      : _repository = repository,
        _location = locationGateway,
        super(const CameraMapState());
  final CameraMapRepository _repository;
  final CameraLocationGateway _location;
  Timer? _debounce;
  CancelToken? _request;
  int _generation = 0, _locationGeneration = 0, _permissionGeneration = 0;
  bool _active = true, _foreground = true;
  bool get _canQuery => _active && _foreground && !isClosed;

  void _invalidate({bool location = false}) {
    _generation++;
    _debounce?.cancel();
    _debounce = null;
    _request?.cancel('Map query changed');
    _request = null;
    if (location) _locationGeneration++;
  }

  void setViewport(MapBounds bounds,
      {double? latitude, double? longitude, double? zoom}) {
    if (isClosed) return;
    emit(state.copyWith(
        bounds: bounds, latitude: latitude, longitude: longitude, zoom: zoom));
    if (state.mode == CameraMapMode.viewport) _schedule();
  }

  void showViewport() {
    if (isClosed) return;
    _invalidate(location: true);
    emit(state.copyWith(
        mode: CameraMapMode.viewport, locating: false, locationStatus: null));
    _schedule();
  }

  Future<void> showNearby() async {
    if (!_canQuery || state.locating) return;
    _invalidate(location: true);
    final generation = _locationGeneration;
    emit(state.copyWith(
        mode: CameraMapMode.nearby,
        locating: true,
        loading: false,
        failure: null,
        locationStatus: null,
        invalidViewport: false,
        query: null));
    CameraLocationResult result;
    try {
      result = await _location.locate();
    } catch (_) {
      result = const CameraLocationResult(status: CameraLocationStatus.failure);
    }
    if (isClosed || !_active || generation != _locationGeneration) return;
    final granted = result.status == CameraLocationStatus.granted &&
        result.lat != null &&
        result.lng != null &&
        result.lat!.isFinite &&
        result.lng!.isFinite &&
        result.lat!.abs() <= 90 &&
        result.lng!.abs() <= 180;
    emit(state.copyWith(
        locating: false,
        locationStatus: granted
            ? CameraLocationStatus.granted
            : (result.status == CameraLocationStatus.granted
                ? CameraLocationStatus.failure
                : result.status),
        locationPermission: granted,
        latitude: granted ? result.lat : null,
        longitude: granted ? result.lng : null,
        nearbyLat: granted ? result.lat : null,
        nearbyLng: granted ? result.lng : null,
        zoom: granted ? 14 : null));
    if (granted) {
      _permissionGeneration++;
      _schedule(immediate: true);
    }
  }

  void setRadius(int meters) {
    if (isClosed ||
        ![1000, 2000, 5000].contains(meters) ||
        state.radiusMeters == meters) {
      return;
    }
    _invalidate(location: true);
    emit(state.copyWith(radiusMeters: meters, locating: false));
    _schedule(immediate: true);
  }

  void setDistrict(String? district) {
    if (isClosed || state.district == district) return;
    _invalidate(location: true);
    emit(state.copyWith(district: district, locating: false));
    _schedule(immediate: true);
  }

  CameraMapQuery? _query() => state.mode == CameraMapMode.viewport
      ? (state.bounds == null
          ? null
          : CameraMapQuery.viewport(
              bounds: state.bounds!, district: state.district))
      : (state.nearbyLat == null || state.nearbyLng == null
          ? null
          : CameraMapQuery.nearby(
              lat: state.nearbyLat!,
              lng: state.nearbyLng!,
              radiusMeters: state.radiusMeters,
              district: state.district));
  void _schedule({bool immediate = false}) {
    _invalidate();
    final query = _query();
    final invalid = state.mode == CameraMapMode.viewport &&
        state.bounds != null &&
        !state.bounds!.isValid;
    emit(
        state.copyWith(query: query, invalidViewport: invalid, loading: false));
    if (!_canQuery || query == null || !query.isValid) {
      return;
    }
    final generation = _generation;
    if (immediate) {
      unawaited(_search(query, generation));
    } else {
      _debounce = Timer(
          const Duration(milliseconds: 400), () => _search(query, generation));
    }
  }

  Future<void> _search(CameraMapQuery query, int generation) async {
    if (!_canQuery || generation != _generation) return;
    final token = CancelToken();
    _request = token;
    emit(state.copyWith(loading: true, failure: null));
    try {
      final result = await _repository.search(query, cancelToken: token);
      if (!_canQuery || generation != _generation || token.isCancelled) return;
      result.fold(
          (failure) => emit(state.copyWith(loading: false, failure: failure)),
          (data) => emit(state.copyWith(
              loading: false,
              result: data,
              resultQuery: query,
              failure: null)));
    } catch (_) {
      if (_canQuery && generation == _generation) {
        emit(state.copyWith(
            loading: false,
            failure:
                const NetworkFailure('Không thể tải camera trong vùng này.')));
      }
    }
  }

  void retry() {
    if (isClosed) return;
    if (state.mode == CameraMapMode.nearby &&
        state.locationStatus != CameraLocationStatus.granted) {
      unawaited(showNearby());
    } else {
      _schedule(immediate: true);
    }
  }

  void setActive(bool active) {
    if (isClosed || _active == active) return;
    _active = active;
    _permissionGeneration++;
    if (!active) {
      _invalidate(location: true);
      emit(state.copyWith(
          loading: false, locating: false, locationPermission: false));
    } else {
      _schedule(immediate: true);
      unawaited(recheckPermission());
    }
  }

  void setForeground(bool foreground) {
    if (isClosed || _foreground == foreground) return;
    _foreground = foreground;
    _permissionGeneration++;
    if (!foreground) {
      _invalidate();
      emit(state.copyWith(loading: false, locationPermission: false));
    } else {
      if (!state.locating) _schedule(immediate: true);
      unawaited(recheckPermission());
    }
  }

  Future<void> recheckPermission() async {
    final generation = ++_permissionGeneration;
    bool granted = false;
    try {
      granted = await _location.checkPermission();
    } catch (_) {}
    if (_canQuery && generation == _permissionGeneration) {
      emit(state.copyWith(locationPermission: granted));
    }
  }

  Future<bool> openAppSettings() => _location.openAppSettings();
  Future<bool> openLocationSettings() => _location.openLocationSettings();
  @override
  Future<void> close() {
    _invalidate(location: true);
    _permissionGeneration++;
    return super.close();
  }
}
