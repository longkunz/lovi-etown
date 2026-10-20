import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';

/// Navigation handoff for a camera (T10): opens the user's maps app with the
/// camera's coordinates as the destination. Prefers the cross-platform
/// Google Maps directions URL; falls back to a plain `geo:` URI when that
/// cannot be launched (e.g. no browser/maps handler for https).
Uri googleMapsDirectionsUri(double latitude, double longitude) {
  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
  );
}

Uri geoDirectionsUri(double latitude, double longitude) {
  return Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
}

/// Launches directions for [camera]. Returns false without launching when the
/// camera has no known location. [launcher] is injectable for tests.
Future<bool> openCameraDirections(
  Camera camera, {
  Future<bool> Function(Uri uri)? launcher,
}) async {
  if (!camera.hasLocation) return false;
  final launch = launcher ??
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  final latitude = camera.latitude!;
  final longitude = camera.longitude!;
  try {
    if (await launch(googleMapsDirectionsUri(latitude, longitude))) {
      return true;
    }
  } catch (_) {
    // Fall through to the geo: URI below.
  }
  try {
    return await launch(geoDirectionsUri(latitude, longitude));
  } catch (_) {
    return false;
  }
}
