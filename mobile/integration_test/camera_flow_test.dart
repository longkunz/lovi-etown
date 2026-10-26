import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_viewer_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_district_picker.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_filters.dart';
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

  Widget buildViewerApp({
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
            home: CameraViewerScreen(
              cameraId: 'cam-uuid-0',
              repository: cameraRepo,
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

    // 2. Apply a district filter and require every display mode control.
    final districtPicker = find.byType(CameraDistrictPicker);
    expect(districtPicker, findsOneWidget);
    await tester.tap(districtPicker);
    await tester.pumpAndSettle();
    final districtOption = find.text('Quan 1 (10)');
    expect(districtOption, findsOneWidget);
    await tester.tap(districtOption);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<CameraFilters>(find.byType(CameraFilters)).selectedDistrict,
      equals('Quan 1'),
    );

    for (final mode in <(String, CameraViewMode)>[
      ('Lưới', CameraViewMode.grid),
      ('Thẻ', CameraViewMode.card),
      ('Danh sách', CameraViewMode.list),
    ]) {
      final modeButton = find.byTooltip(mode.$1);
      expect(modeButton, findsOneWidget);
      await tester.tap(modeButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<CameraFilters>(find.byType(CameraFilters)).viewMode,
        equals(mode.$2),
      );
    }

    // 3. Search query filter (mandatory, not conditionally skipped).
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Nguyen Hue');
    await tester.pump(const Duration(milliseconds: 700));
    // Leave enough viewport for the filtered item before locating its
    // trailing actions on a real device or a compact emulator.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 20 && find.byType(CameraTile).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CameraTile), findsWidgets);
    final activeFilters =
        tester.widget<CameraFilters>(find.byType(CameraFilters));
    expect(activeFilters.query, equals('Nguyen Hue'));
    expect(activeFilters.selectedDistrict, equals('Quan 1'));
    expect(activeFilters.viewMode, equals(CameraViewMode.list));

    // 4. Save star to favorites from tile
    final firstTile = find.byType(CameraTile).hitTestable().first;
    final anchorCamera = tester.widget<CameraTile>(firstTile).camera;
    final favoriteButton = find
        .descendant(
          of: firstTile,
          matching: find.byTooltip('Quan tâm'),
        )
        .hitTestable();
    expect(favoriteButton, findsOneWidget);
    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    // Verify favorite added to repository
    final favs = await favRepo.load();
    expect(favs.getOrElse((_) => []).length, equals(1));

    // 5. Open the current camera detail screen. Avoid pumpAndSettle here:
    // preview polling intentionally keeps timers armed while this route is up.
    await tester.tap(firstTile);
    for (var i = 0;
        i < 20 && find.byType(CameraViewerScreen).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(CameraViewerScreen), findsOneWidget);

    // 6. Open the zoomable full-screen media page.
    final fullScreenButton =
        find.byKey(const ValueKey('viewer_fullscreen_button'));
    expect(fullScreenButton, findsOneWidget);
    await tester.tap(fullScreenButton);
    for (var i = 0;
        i < 20 &&
            find
                .byKey(const ValueKey('viewer_fullscreen_page'))
                .evaluate()
                .isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.byKey(const ValueKey('viewer_fullscreen_page')),
      findsOneWidget,
    );

    // Double-tap to zoom
    final interactiveViewer = find.byType(InteractiveViewer);
    expect(interactiveViewer, findsOneWidget);
    await tester.tap(interactiveViewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(interactiveViewer);
    // The viewer intentionally keeps a polling/countdown animation alive, so
    // waiting for the whole tree to settle can block until the test timeout.
    await tester.pump(const Duration(milliseconds: 400));

    // Close full-screen media with its explicit affordance.
    final closeViewerBtn =
        find.byKey(const ValueKey('viewer_fullscreen_close'));
    await tester.tap(closeViewerBtn);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('viewer_fullscreen_page')),
      findsNothing,
    );

    // 7. Return from detail to the catalog.
    final detailBackButton = find.byType(BackButton);
    expect(detailBackButton, findsOneWidget);
    await tester.tap(detailBackButton);
    for (var i = 0;
        i < 20 && find.byType(CameraViewerScreen).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CameraViewerScreen), findsNothing);

    // 8. Verify Back preserved the complete catalog context and anchor.
    final restoredFilters =
        tester.widget<CameraFilters>(find.byType(CameraFilters));
    expect(restoredFilters.query, equals('Nguyen Hue'));
    expect(restoredFilters.selectedDistrict, equals('Quan 1'));
    expect(restoredFilters.viewMode, equals(CameraViewMode.list));
    final restoredAnchor =
        find.byKey(ValueKey<String>('cam_${anchorCamera.id}'));
    expect(restoredAnchor, findsOneWidget);
    expect(tester.widget<CameraTile>(restoredAnchor).isFavorite, isTrue);
    final restoredFavorites = await favRepo.load();
    expect(
      restoredFavorites.getOrElse((_) => const []).map((item) => item.id),
      contains(anchorCamera.id),
    );
  });

  testWidgets('preview lifecycle keeps exactly one polling chain',
      (tester) async {
    final cameraRepo = FakeIntegrationCameraRepository()
      ..snapshotFailuresRemaining = 1;
    final favRepo = InMemoryFavoritesRepository();

    await tester
        .pumpWidget(buildViewerApp(cameraRepo: cameraRepo, favRepo: favRepo));
    for (var i = 0; i < 20 && cameraRepo.snapshotCallCount == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(cameraRepo.snapshotCallCount, equals(1));

    // The first simulated 503 schedules one recovery attempt after 12s.
    await tester.pump(const Duration(seconds: 12));
    for (var i = 0; i < 20 && cameraRepo.snapshotCallCount == 1; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(cameraRepo.snapshotCallCount, equals(2));
    final callsAfterRecovery = cameraRepo.snapshotCallCount;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 13));
    expect(cameraRepo.snapshotCallCount, equals(callsAfterRecovery));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0;
        i < 20 && cameraRepo.snapshotCallCount == callsAfterRecovery;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(cameraRepo.snapshotCallCount, equals(callsAfterRecovery + 1));

    // Exactly one scheduled refresh follows the immediate resume refresh.
    await tester.pump(const Duration(seconds: 12));
    for (var i = 0;
        i < 20 && cameraRepo.snapshotCallCount == callsAfterRecovery + 1;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(cameraRepo.snapshotCallCount, equals(callsAfterRecovery + 2));

    debugPrint(
      'T03_LIFECYCLE recovery=$callsAfterRecovery '
      'background=$callsAfterRecovery '
      'resume=${cameraRepo.snapshotCallCount}',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final callsAfterDismiss = cameraRepo.snapshotCallCount;
    await tester.pump(const Duration(seconds: 13));
    expect(cameraRepo.snapshotCallCount, equals(callsAfterDismiss));
    debugPrint('T03_DISMISS calls=$callsAfterDismiss stable=true');
  });
}
