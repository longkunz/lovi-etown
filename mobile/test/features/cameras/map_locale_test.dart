import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/config/map_config.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_canvas.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  testWidgets('missing map key message uses English', (tester) async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('vi')],
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('vi'),
      saveLocale: false,
      path: 'assets/translations',
      child: Builder(
          builder: (context) => MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const CameraMapCanvas(
                    connectionConfig: MapConnectionConfig(),
                    config: CameraMapViewConfig(
                        center: MapCoordinate(10, 106),
                        zoom: 12,
                        trafficEnabled: true,
                        markers: [])),
              )),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Vietmap key is not configured'), findsOneWidget);
  });
}
