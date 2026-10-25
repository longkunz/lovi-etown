import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_tile.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('grid aligns images and labels at text scale $textScale',
        (tester) async {
      const cameras = [
        Camera(
            id: 'short',
            name: 'Lê Lợi',
            provinceId: 'hcm',
            district: 'Quận 1',
            playbackEndpoint: '/short/playback'),
        Camera(
          id: 'long',
          name: 'Nguyễn Thị Minh Khai - Nam Kỳ Khởi Nghĩa',
          provinceId: 'hcm',
          district: 'Quận 3',
          playbackEndpoint: '/long/playback',
        ),
        Camera(
            id: 'no-district',
            name: 'Huế',
            provinceId: 'hcm',
            playbackEndpoint: '/no-district/playback'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final camera in cameras)
                  SizedBox(
                    width: 144,
                    height: 160,
                    child: CameraTile(
                      camera: camera,
                      viewMode: CameraViewMode.grid,
                      onToggleFavorite: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();

      final shortName = tester.getTopLeft(find.text('Lê Lợi'));
      expect(tester.getTopLeft(find.text(cameras[1].name)).dy, shortName.dy);
      expect(tester.getTopLeft(find.text('Huế')).dy, shortName.dy);
      expect(tester.getTopLeft(find.text('Quận 1')).dy,
          tester.getTopLeft(find.text('Quận 3')).dy);
      expect(tester.takeException(), isNull);
    });
  }
}
