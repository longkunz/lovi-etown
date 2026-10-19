// T05 (code level) — layout & accessibility guards for the camera screen:
// narrow viewports, large font scale, dark theme, reduced motion and
// semantics labels. Device-only checks (TalkBack/VoiceOver walkthrough,
// frame timing, memory) stay in the T05 device session; these widget tests
// pin the parts that can regress silently in code review.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_tile.dart';
import 'package:flutter_starter/src/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/camera_fakes.dart';

/// In-memory translations, mirroring camera_screen_test.dart: loading the
/// real asset bundle hangs on repeated pumps across tests in one file.
class _FakeAssetLoader extends AssetLoader {
  const _FakeAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'shared': {
        'retry': 'Thử lại',
        'close': 'Đóng',
        'demo_mode_badge': 'Dữ liệu mẫu',
      },
      'camera': {
        'title': 'Camera giao thông',
        'search_hint': 'Tìm tên đường, giao lộ...',
        'all_districts': 'Tất cả quận/huyện',
        'favorites_title': 'Quan tâm',
        'empty_favorites': 'Chưa có camera quan tâm',
        'view_card': 'Thẻ',
        'view_grid': 'Lưới',
        'view_list': 'Danh sách',
      },
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // EasyLocalization persists the locale via SharedPreferences; without a
    // mock the first test passes and later pumps never finish loading.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
    await AppConfig.init(
      config: const CameraConnectionConfig(
        baseUrl: 'http://localhost:3000',
        readerKey: 'test-key',
        demoMode: true,
      ),
    );
  });

  Widget buildApp(
    WidgetTester tester, {
    bool dark = false,
    double textScale = 1.0,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const _FakeAssetLoader(),
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: dark
                  ? buildDarkTheme(primaryColorHex: '#00897B')
                  : buildLightTheme(primaryColorHex: '#00897B'),
              home: CameraFeature(
                cameraRepository: FakeIntegrationCameraRepository(),
                favoritesRepository: InMemoryFavoritesRepository(),
              ),
            );
          },
        ),
      ),
    );
  }


  Future<void> pumpUntilTiles(WidgetTester tester) async {
    // The catalog loads asynchronously; pump in steps until tiles appear
    // instead of pumpAndSettle, which can settle before the load lands.
    for (var i = 0; i < 30 && find.byType(CameraTile).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  void useViewport(WidgetTester tester, double widthDp) {
    tester.view.physicalSize = Size(widthDp * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('T05: 320dp viewport renders camera list without overflow',
      (tester) async {
    useViewport(tester, 320);
    await tester.pumpWidget(buildApp(tester));
    await pumpUntilTiles(tester);
    expect(find.byType(CameraTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T05: 390dp viewport renders camera list without overflow',
      (tester) async {
    useViewport(tester, 390);
    await tester.pumpWidget(buildApp(tester));
    await pumpUntilTiles(tester);
    expect(find.byType(CameraTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T05: font scale 2.0 keeps list usable at 390dp and 320dp',
      (tester) async {
    useViewport(tester, 390);
    await tester.pumpWidget(buildApp(tester, textScale: 2));
    await pumpUntilTiles(tester);
    expect(find.byType(CameraTile), findsWidgets);
    expect(tester.takeException(), isNull);

    useViewport(tester, 320);
    await tester.pumpWidget(buildApp(tester, textScale: 2));
    await pumpUntilTiles(tester);
    expect(find.byType(CameraTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T05: dark theme renders camera list without exceptions',
      (tester) async {
    useViewport(tester, 390);
    await tester.pumpWidget(buildApp(tester, dark: true));
    await pumpUntilTiles(tester);
    expect(find.byType(CameraTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T05: reduced motion (disableAnimations) renders fine',
      (tester) async {
    useViewport(tester, 390);
    await tester.pumpWidget(buildApp(tester, disableAnimations: true));
    await pumpUntilTiles(tester);
    expect(find.byType(CameraTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T05: favorite toggle exposes a semantics label',
      (tester) async {
    final handle = tester.ensureSemantics();
    useViewport(tester, 390);
    await tester.pumpWidget(buildApp(tester));
    await pumpUntilTiles(tester);
    expect(find.bySemanticsLabel('Quan tâm'), findsWidgets);
    handle.dispose();
  });
}
