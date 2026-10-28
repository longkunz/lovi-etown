import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/weather_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherFixture implements WeatherRepository {
  @override
  Future<WeatherSnapshot?> current() async => WeatherSnapshot(
        temperatureC: 28,
        weatherCode: 80,
        tempMaxC: 33,
        tempMinC: 25,
        fetchedAt: DateTime(2026),
      );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  testWidgets('English weather card translates condition and temperatures',
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
                home: WeatherCard(repository: WeatherFixture()),
              )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('28°C · Showers'), findsOneWidget);
    expect(find.textContaining('High 33°'), findsOneWidget);
    expect(find.textContaining('Low 25°'), findsOneWidget);
  });
}
