import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_tile.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';

class _TileLoader extends AssetLoader {
  const _TileLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'camera': {
          'favorite': 'Quan tâm',
          'unfavorite': 'Bỏ quan tâm',
        },
      };
}

Widget _app(Widget home) => EasyLocalization(
      supportedLocales: const [Locale('vi')],
      path: 'assets/translations',
      assetLoader: const _TileLoader(),
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'),
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: home,
        ),
      ),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final mode in [CameraViewMode.card, CameraViewMode.grid]) {
    testWidgets('$mode favorite keeps compact glass and a 48px tap target',
        (tester) async {
      var toggles = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: SizedBox(
            width: 200,
            height: 350,
            child: CameraTile(
              camera: const Camera(
                id: 'favorite',
                name: 'Lê Lợi',
                provinceId: 'tp_hcm',
                playbackEndpoint: '/favorite/playback',
              ),
              viewMode: mode,
              isFavorite: true,
              onToggleFavorite: () => toggles++,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final favorite = find.byTooltip('Bỏ quan tâm');
      expect(tester.getSize(favorite), const Size(48, 48));
      expect(
          tester.getSize(find.byType(CameraGlassSurface)), const Size(32, 32));
      expect(tester.widget<Icon>(find.byIcon(Icons.star)).size, 20);
      // The corner is outside the visible 32px control but must remain tappable.
      await tester.tapAt(tester.getTopLeft(favorite) + const Offset(1, 1));
      expect(toggles, 1);
      expect(tester.takeException(), isNull);
    });
  }

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
