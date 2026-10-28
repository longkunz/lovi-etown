import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/theme/theme.dart';
import 'package:flutter_starter/src/shared/widgets/ui/app/app_platform.dart';
import 'package:flutter_starter/src/routing/app_router.dart';
import 'package:flutter_starter/src/routing/app_routes.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_navigation_shell.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_map_screen.dart';
import 'camera_screen_test.dart'
    show FakeScreenCameraRepository, FakeFavoritesRepository;
import 'camera_navigation_test.dart' show NavigationMapRepository;
import '../../app_boot_test.dart' show TestAssetLoader;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() {
    AppConfig.cameraConfig = const CameraConnectionConfig(
        baseUrl: '', readerKey: '', demoMode: true);
  });

  testWidgets('onboarding Get Started goes straight to the Map shell',
      (tester) async {
    final router = createAppRouter(
        navigatorKey: GlobalKey<NavigatorState>(),
        initialLocation: AppRoutes.onboarding,
        cameraRepository: FakeScreenCameraRepository(),
        favoritesRepository: FakeFavoritesRepository(),
        mapRepository: NavigationMapRepository());
    addTearDown(router.dispose);
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const TestAssetLoader(),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: Builder(
            builder: (context) => AppPlatformScope(
                style: AppPlatformStyle.cupertino,
                child: MaterialApp.router(
                    routerConfig: router,
                    localizationsDelegates: context.localizationDelegates,
                    supportedLocales: context.supportedLocales,
                    locale: context.locale,
                    builder: (context, child) => Theme(
                        data: buildLightTheme(primaryColorHex: '#00796B'),
                        child: child!))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraNavigationShell), findsOneWidget);
    expect(find.byType(CameraMapScreen), findsOneWidget);
  });
}
