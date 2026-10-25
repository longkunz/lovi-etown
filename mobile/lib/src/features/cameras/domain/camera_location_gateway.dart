enum CameraLocationStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  failure
}

class CameraLocationResult {
  final CameraLocationStatus status;
  final double? lat, lng, accuracyMeters;
  const CameraLocationResult(
      {required this.status, this.lat, this.lng, this.accuracyMeters});
}

abstract interface class CameraLocationGateway {
  Future<CameraLocationResult> locate();
  Future<bool> checkPermission();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}
