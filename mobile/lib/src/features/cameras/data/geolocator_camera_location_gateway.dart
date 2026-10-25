import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../domain/camera_location_gateway.dart';

class GeolocatorCameraLocationGateway implements CameraLocationGateway {
  final GeolocatorPlatform platform;
  final Duration timeout;
  GeolocatorCameraLocationGateway(
      {GeolocatorPlatform? platform,
      this.timeout = const Duration(seconds: 10)})
      : platform = platform ?? GeolocatorPlatform.instance;
  bool _granted(LocationPermission permission) =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
  @override
  Future<bool> checkPermission() async {
    try {
      return await platform.isLocationServiceEnabled() &&
          _granted(await platform.checkPermission());
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CameraLocationResult> locate() async {
    try {
      if (!await platform.isLocationServiceEnabled()) {
        return const CameraLocationResult(
            status: CameraLocationStatus.serviceDisabled);
      }
      var permission = await platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await platform.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const CameraLocationResult(
            status: CameraLocationStatus.deniedForever);
      }
      if (!_granted(permission)) {
        return const CameraLocationResult(status: CameraLocationStatus.denied);
      }
      final position = await platform
          .getCurrentPosition(
              locationSettings: LocationSettings(
                  accuracy: LocationAccuracy.high, timeLimit: timeout))
          .timeout(timeout);
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        return const CameraLocationResult(status: CameraLocationStatus.failure);
      }
      return CameraLocationResult(
          status: CameraLocationStatus.granted,
          lat: position.latitude,
          lng: position.longitude,
          accuracyMeters: position.accuracy);
    } on TimeoutException {
      return const CameraLocationResult(status: CameraLocationStatus.timeout);
    } catch (_) {
      return const CameraLocationResult(status: CameraLocationStatus.failure);
    }
  }

  @override
  Future<bool> openAppSettings() => platform.openAppSettings();
  @override
  Future<bool> openLocationSettings() => platform.openLocationSettings();
}
