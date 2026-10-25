import 'camera_models.dart';

class MapBounds {
  final double west, south, east, north;
  const MapBounds(this.west, this.south, this.east, this.north);
  bool get isValid =>
      [west, south, east, north].every((v) => v.isFinite) &&
      west >= -180 &&
      east <= 180 &&
      south >= -90 &&
      north <= 90 &&
      west < east &&
      south < north;
}

class CameraMapQuery {
  final MapBounds? bounds;
  final double? lat, lng;
  final int radiusMeters, limit;
  final String? district;
  const CameraMapQuery.viewport(
      {required MapBounds this.bounds, this.district, this.limit = 200})
      : lat = null,
        lng = null,
        radiusMeters = 2000;
  const CameraMapQuery.nearby(
      {required double this.lat,
      required double this.lng,
      this.radiusMeters = 2000,
      this.district,
      this.limit = 200})
      : bounds = null;
  bool get isNearby => bounds == null;
  bool get isValid =>
      limit >= 1 &&
      limit <= 200 &&
      (district?.trim().length ?? 0) <= 80 &&
      (isNearby
          ? lat != null &&
              lng != null &&
              lat!.isFinite &&
              lng!.isFinite &&
              lat! >= -90 &&
              lat! <= 90 &&
              lng! >= -180 &&
              lng! <= 180 &&
              radiusMeters >= 100 &&
              radiusMeters <= 5000
          : bounds!.isValid);
}

class CameraMapItem {
  final Camera camera;
  final double? distanceMeters;
  const CameraMapItem({required this.camera, this.distanceMeters});
}

class CameraMapResult {
  final List<CameraMapItem> items;
  final bool hasMore, isStale;
  final String catalogVersion, dataMode;
  final DateTime? fetchedAt;
  final String? coverage, syncState;
  const CameraMapResult(
      {required this.items,
      required this.hasMore,
      required this.catalogVersion,
      this.fetchedAt,
      this.isStale = false,
      this.coverage,
      this.syncState,
      this.dataMode = 'real'});
}
