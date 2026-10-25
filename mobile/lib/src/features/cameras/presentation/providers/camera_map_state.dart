import '../../domain/camera_map_models.dart';
import '../../domain/camera_location_gateway.dart';
import '../../../../utils/failure.dart';

enum CameraMapMode { viewport, nearby }

const _unset = Object();

class CameraMapState {
  const CameraMapState(
      {this.mode = CameraMapMode.viewport,
      this.bounds,
      this.radiusMeters = 2000,
      this.district,
      this.latitude = 10.7769,
      this.longitude = 106.7009,
      this.zoom = 13,
      this.nearbyLat,
      this.nearbyLng,
      this.query,
      this.resultQuery,
      this.result,
      this.failure,
      this.loading = false,
      this.locating = false,
      this.locationStatus,
      this.locationPermission = false,
      this.invalidViewport = false});
  final CameraMapMode mode;
  final MapBounds? bounds;
  final int radiusMeters;
  final String? district;
  final double latitude, longitude, zoom;
  final double? nearbyLat, nearbyLng;
  final CameraMapQuery? query, resultQuery;
  final CameraMapResult? result;
  final Failure? failure;
  final bool loading, locating, locationPermission, invalidViewport;
  final CameraLocationStatus? locationStatus;
  bool get resultsAreStale =>
      result != null &&
      (result!.isStale ||
          !identical(query, resultQuery) ||
          failure != null ||
          loading);
  bool get updateRequired =>
      failure is ApiFailure && (failure as ApiFailure).statusCode == 401;

  CameraMapState copyWith(
          {CameraMapMode? mode,
          MapBounds? bounds,
          int? radiusMeters,
          Object? district = _unset,
          double? latitude,
          double? longitude,
          double? zoom,
          double? nearbyLat,
          double? nearbyLng,
          Object? query = _unset,
          CameraMapQuery? resultQuery,
          CameraMapResult? result,
          Object? failure = _unset,
          bool? loading,
          bool? locating,
          Object? locationStatus = _unset,
          bool? locationPermission,
          bool? invalidViewport}) =>
      CameraMapState(
          mode: mode ?? this.mode,
          bounds: bounds ?? this.bounds,
          radiusMeters: radiusMeters ?? this.radiusMeters,
          district:
              identical(district, _unset) ? this.district : district as String?,
          latitude: latitude ?? this.latitude,
          longitude: longitude ?? this.longitude,
          zoom: zoom ?? this.zoom,
          nearbyLat: nearbyLat ?? this.nearbyLat,
          nearbyLng: nearbyLng ?? this.nearbyLng,
          query:
              identical(query, _unset) ? this.query : query as CameraMapQuery?,
          resultQuery: resultQuery ?? this.resultQuery,
          result: result ?? this.result,
          failure:
              identical(failure, _unset) ? this.failure : failure as Failure?,
          loading: loading ?? this.loading,
          locating: locating ?? this.locating,
          locationStatus: identical(locationStatus, _unset)
              ? this.locationStatus
              : locationStatus as CameraLocationStatus?,
          locationPermission: locationPermission ?? this.locationPermission,
          invalidViewport: invalidViewport ?? this.invalidViewport);
}
