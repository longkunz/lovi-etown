import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_image_viewer.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_tile.dart';
import 'package:flutter_starter/src/theme/theme.dart';
import '../test/support/camera_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

    // 5. Open snapshot sheet
    final firstTile = find.byType(CameraTile).first;
    await tester.tap(firstTile);
    await tester.pumpAndSettle();

    expect(find.byType(CameraSnapshotSheet), findsOneWidget);

    // 6. Tap image to open zoom/rotate viewer
    final sheetImage = find.byKey(const ValueKey('snapshot_sheet_image'));
    expect(sheetImage, findsOneWidget);
    await tester.tap(sheetImage);
    await tester.pumpAndSettle();

    expect(find.byType(CameraImageViewer), findsOneWidget);

    // Double-tap to zoom
    final interactiveViewer = find.byType(InteractiveViewer);
    expect(interactiveViewer, findsOneWidget);
    await tester.tap(interactiveViewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(interactiveViewer);
    await tester.pumpAndSettle();

    // Close viewer with close button
    final closeViewerBtn = find.byIcon(Icons.close).last;
    await tester.tap(closeViewerBtn);
    await tester.pumpAndSettle();
    expect(find.byType(CameraImageViewer), findsNothing);

    // 7. Close sheet with handle or close button
    final closeSheetBtn = find.byIcon(Icons.close).first;
    await tester.tap(closeSheetBtn);
    await tester.pumpAndSettle();
    expect(find.byType(CameraSnapshotSheet), findsNothing);

    // 8. Verify camera items still present with same anchor
    expect(find.byType(CameraTile), findsWidgets);
  });
}
