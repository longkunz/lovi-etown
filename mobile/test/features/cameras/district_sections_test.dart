import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/district_sections.dart';

Camera cam(String id, String? district) => Camera(
      id: id,
      name: 'Cam $id',
      provinceId: 'tp_hcm',
      district: district,
      playbackEndpoint: '/v1/cameras/$id/playback',
    );

void main() {
  group('buildDistrictSections', () {
    test('groups by district in first-appearance order with counts', () {
      final entries = buildDistrictSections([
        cam('1', 'Quận 3'),
        cam('2', 'Quận 1'),
        cam('3', 'Quận 3'),
      ]);
      final headers = entries.whereType<DistrictHeaderEntry>().toList();
      expect(headers.map((h) => h.name), ['Quận 3', 'Quận 1']);
      expect(headers.map((h) => h.count), [2, 1]);
      expect(entries.whereType<CameraEntry>().map((e) => e.camera.id),
          ['1', '3', '2']);
    });

    test('null/blank districts fall into a final "Khác" section', () {
      final entries = buildDistrictSections([
        cam('1', null),
        cam('2', 'Quận 1'),
        cam('3', '  '),
      ]);
      final headers = entries.whereType<DistrictHeaderEntry>().toList();
      expect(headers.map((h) => h.name), ['Quận 1', 'Khác']);
      expect(headers.last.count, 2);
    });

    test('empty input -> empty output', () {
      expect(buildDistrictSections(const []), isEmpty);
    });

    test('trims district labels before grouping', () {
      final entries = buildDistrictSections([
        cam('1', ' Quận 3 '),
        cam('2', 'Quận 3'),
      ]);
      final headers = entries.whereType<DistrictHeaderEntry>().toList();
      expect(headers, hasLength(1));
      expect(headers.single.name, 'Quận 3');
      expect(headers.single.count, 2);
    });
  });
}
