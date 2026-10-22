import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_viewer_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_tile.dart';
import 'package:flutter_starter/src/theme/theme.dart';
import '../../support/camera_fakes.dart';

void main() {
  setUpAll(() async {
    EasyLocalization.logger.enableLevels = [];
    await AppConfig.init(
      config: const CameraConnectionConfig(
        baseUrl: 'http://localhost:3000',
        readerKey: 'test-key',
        demoMode: true,
      ),
    );
  });

  Widget buildApp({
    required FakeIntegrationCameraRepository cameraRepo,
    required InMemoryFavoritesRepository favRepo,
  }) {
    return EasyLocalization(
      supportedLocales: const [Locale('vi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi'),
      startLocale: const Locale('vi'),
      child: Builder(
        builder: (context) {
          return MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: buildLightTheme(primaryColorHex: '#00897B'),
            home: CameraFeature(
              cameraRepository: cameraRepo,
              favoritesRepository: favRepo,
            ),
          );
        },
      ),
    );
  }

  testWidgets('camera full user flow integration test', (tester) async {
    final cameraRepo = FakeIntegrationCameraRepository();
    final favRepo = InMemoryFavoritesRepository();

    await tester.pumpWidget(buildApp(cameraRepo: cameraRepo, favRepo: favRepo));
    await tester.pumpAndSettle();

    // 1. Verify screen loaded with camera items
    expect(find.byType(CameraFeature), findsOneWidget);
    expect(find.byType(CameraTile), findsWidgets);

    // 2. Switch display mode to Card and List
    final cardButton = find.byTooltip('Chế độ thẻ');
    if (cardButton.evaluate().isNotEmpty) {
      await tester.tap(cardButton);
      await tester.pumpAndSettle();
    }

    final listButton = find.byTooltip('Chế độ danh sách');
    if (listButton.evaluate().isNotEmpty) {
      await tester.tap(listButton);
      await tester.pumpAndSettle();
    }

    // 3. Search query filter
    final searchField = find.byType(TextField);
    if (searchField.evaluate().isNotEmpty) {
      await tester.enterText(searchField, 'Nguyen Hue');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(CameraTile), findsWidgets);
    }

    // 4. Save star to favorites from tile
    final starButton = find.byIcon(Icons.star_border).first;
    await tester.tap(starButton);
    await tester.pumpAndSettle();

    // Verify favorite added to repository
    final favs = await favRepo.load();
    expect(favs.getOrElse((_) => []).length, equals(1));

    // 5. Open the full-screen camera viewer
    final firstTile = find.byType(CameraTile).first;
    await tester.tap(firstTile);
    await tester.pumpAndSettle();

    expect(find.byType(CameraViewerScreen), findsOneWidget);

    // 6. Tap image to open the full-screen media page
    final viewerImage = find.byKey(const ValueKey('viewer_snapshot_image'));
    expect(viewerImage, findsOneWidget);
    await tester.tap(viewerImage);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('viewer_fullscreen_page')), findsOneWidget);

    // Interactive zoom surface is available in full screen
    final interactiveViewer = find.byType(InteractiveViewer);
    expect(interactiveViewer, findsOneWidget);
    await tester.tap(interactiveViewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(interactiveViewer);
    await tester.pumpAndSettle();

    // Close full screen with its close button
    final closeViewerBtn = find.byKey(const ValueKey('viewer_fullscreen_close'));
    await tester.tap(closeViewerBtn);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('viewer_fullscreen_page')), findsNothing);
    expect(find.byType(CameraViewerScreen), findsOneWidget);

    // 7. Go back from the viewer to the catalog
    final backBtn = find.byIcon(Icons.arrow_back).first;
    await tester.tap(backBtn);
    await tester.pumpAndSettle();
    expect(find.byType(CameraViewerScreen), findsNothing);

    // 8. Verify camera items still present with same anchor
    expect(find.byType(CameraTile), findsWidgets);
  });
}
