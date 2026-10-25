import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_starter/src/features/cameras/data/geolocator_camera_location_gateway.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_location_gateway.dart';

class FakeLocation extends GeolocatorPlatform {
  bool enabled = true, hanging = false;
  LocationPermission permission = LocationPermission.whileInUse;
  int requests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    if (hanging) return Completer<Position>().future;
    return Position(
        latitude: 10,
        longitude: 106,
        timestamp: DateTime.now(),
        accuracy: 1500,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0);
  }
}

void main() {
  test('granted coarse position is accepted', () async {
    final platform = FakeLocation();
    final result =
        await GeolocatorCameraLocationGateway(platform: platform).locate();
    expect(result.status, CameraLocationStatus.granted);
    expect(result.accuracyMeters, 1500);
    expect(platform.requests, 0);
  });
  test('denied prompts once; resume check never prompts', () async {
    final platform = FakeLocation()..permission = LocationPermission.denied;
    final gateway = GeolocatorCameraLocationGateway(platform: platform);
    expect(await gateway.checkPermission(), false);
    expect(platform.requests, 0);
    expect((await gateway.locate()).status, CameraLocationStatus.denied);
    expect(platform.requests, 1);
  });
  test('permanent denial and disabled service have typed outcomes', () async {
    final platform = FakeLocation()
      ..permission = LocationPermission.deniedForever;
    final gateway = GeolocatorCameraLocationGateway(platform: platform);
    expect((await gateway.locate()).status, CameraLocationStatus.deniedForever);
    expect(platform.requests, 0);
    platform.enabled = false;
    expect(
        (await gateway.locate()).status, CameraLocationStatus.serviceDisabled);
  });
  test('position has a deadline', () async {
    final platform = FakeLocation()..hanging = true;
    final result = await GeolocatorCameraLocationGateway(
            platform: platform, timeout: const Duration(milliseconds: 1))
        .locate();
    expect(result.status, CameraLocationStatus.timeout);
  });
}
