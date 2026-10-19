import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/app.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App should build', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    AppConfig.cameraConfig = const CameraConnectionConfig(
      baseUrl: 'http://localhost:3000',
      readerKey: 'test_key',
      demoMode: true,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(App), findsOneWidget);
  });
}
