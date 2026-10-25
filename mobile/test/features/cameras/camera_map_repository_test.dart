import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_models.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/fixture_camera_map_repository.dart';

class Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode({
        'items': List.generate(
            251,
            (i) => {
                  'id': i.toString().padLeft(3, '0'),
                  'name': 'Camera',
                  'location': {'lat': 10.0 + i / 10000, 'lng': 106.0},
                  'district': 'A'
                })
      }))));
}

void main() {
  test('fixture district and bbox restrict results before limiting', () async {
    final repo = FixtureCameraMapRepository(bundle: Bundle());
    final none = await repo.search(const CameraMapQuery.viewport(
        bounds: MapBounds(105, 9, 107, 11), district: 'B'));
    none.fold((f) => fail('$f'), (v) => expect(v.items, isEmpty));
    final subset = await repo.search(
        const CameraMapQuery.viewport(bounds: MapBounds(105, 10.02, 107, 11)));
    subset.fold((f) => fail('$f'), (v) {
      expect(v.items.first.camera.id, '200');
      expect(v.items.length, 51);
      expect(v.hasMore, false);
    });
  });

  test('bounds reject wrapped coordinates', () {
    expect(const MapBounds(107, 10, 106, 11).isValid, false);
  });
  test('fixture searches entire dataset', () async {
    final repository = FixtureCameraMapRepository(bundle: Bundle());
    final result = await repository.search(
        const CameraMapQuery.viewport(bounds: MapBounds(105, 9, 107, 11)));
    result.fold((f) => fail('$f'), (v) {
      expect(v.items.length, 200);
      expect(v.hasMore, true);
      expect(v.items.first.camera.id, '000');
    });
    final near = await repository.search(
        const CameraMapQuery.nearby(lat: 10, lng: 106, radiusMeters: 1000));
    near.fold((f) => fail('$f'), (v) {
      expect(v.items.first.distanceMeters, 0);
      expect(v.items.last.distanceMeters!, lessThan(1000));
      expect(v.items.length, lessThan(200));
    });
  });
}
