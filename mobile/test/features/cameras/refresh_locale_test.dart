import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_state.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_refresh_countdown.dart';
import 'package:flutter_starter/src/utils/async_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  testWidgets('refresh status uses English when English is selected',
      (tester) async {
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
                home: const Scaffold(
                    body: CameraRefreshCountdown(
                  state: CameraPreviewState(snapshotState: RequestLoading()),
                )),
              )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Refreshing…'), findsOneWidget);
  });
}
