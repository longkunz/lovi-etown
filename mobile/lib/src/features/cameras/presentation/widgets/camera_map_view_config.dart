import 'package:flutter/widgets.dart';
import '../../domain/camera_map_models.dart';

@immutable
class MapCoordinate {
  const MapCoordinate(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

@immutable
class CameraMapMarker {
  const CameraMapMarker(
      {required this.id,
      required this.position,
      required this.title,
      this.onTap});
  final String id;
  final MapCoordinate position;
  final String title;
  final VoidCallback? onTap;
}

enum CameraMapType { street, hybrid }

abstract interface class CameraMapHandle {
  Future<void> moveTo(double latitude, double longitude, {double? zoom});
}

@immutable
class CameraMapViewConfig {
  const CameraMapViewConfig(
      {required this.center,
      required this.zoom,
      required this.trafficEnabled,
      required this.markers,
      this.mapType = CameraMapType.street,
      this.myLocationEnabled = false,
      this.onMapCreated,
      this.onIdle,
      this.radiusMeters,
      this.radiusCenter});
  final MapCoordinate center;
  final double zoom;
  final bool trafficEnabled;
  final Iterable<CameraMapMarker> markers;
  final CameraMapType mapType;
  final bool myLocationEnabled;
  final double? radiusMeters;
  final MapCoordinate? radiusCenter;
  final void Function(CameraMapHandle)? onMapCreated;
  final void Function(MapBounds bounds, double zoom, MapCoordinate center)?
      onIdle;
}

typedef CameraMapViewBuilder = Widget Function(
    BuildContext context, CameraMapViewConfig config);
typedef CameraTrafficMapConfig = CameraMapViewConfig;
