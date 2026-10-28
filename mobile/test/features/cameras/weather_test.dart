import 'package:easy_localization/easy_localization.dart';
import 'localized_widget_test_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/data/open_meteo_weather_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/weather_card.dart';

Map<String, dynamic> samplePayload() => {
      'current': {'temperature_2m': 28.4, 'weather_code': 80},
      'daily': {
        'temperature_2m_max': [33.1],
        'temperature_2m_min': [25.2],
      },
    };

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  group('weatherCodeLabel', () {
    test('maps the main WMO codes to Vietnamese labels', () {
      expect(weatherCodeLabel(0), 'Trời quang');
      expect(weatherCodeLabel(2), 'Có mây');
      expect(weatherCodeLabel(3), 'Nhiều mây');
      expect(weatherCodeLabel(45), 'Sương mù');
      expect(weatherCodeLabel(51), 'Mưa phùn');
      expect(weatherCodeLabel(63), 'Mưa');
      expect(weatherCodeLabel(80), 'Mưa rào');
      expect(weatherCodeLabel(95), 'Dông');
      expect(weatherCodeLabel(999), 'Không rõ');
    });
  });

  group('OpenMeteoWeatherRepository.parseForecast', () {
    test('parses current + daily extremes', () {
      final snap = OpenMeteoWeatherRepository.parseForecast(
        samplePayload(),
        fetchedAt: DateTime(2026, 10, 20, 9),
      );
      expect(snap, isNotNull);
      expect(snap!.temperatureC, 28.4);
      expect(snap.weatherCode, 80);
      expect(snap.tempMaxC, 33.1);
      expect(snap.tempMinC, 25.2);
      expect(snap.conditionLabel, 'Mưa rào');
    });

    test('missing current block -> null', () {
      expect(
        OpenMeteoWeatherRepository.parseForecast({}, fetchedAt: DateTime.now()),
        isNull,
      );
    });
  });

  group('OpenMeteoWeatherRepository.current', () {
    var now = DateTime(2026, 10, 20, 9);
    setUp(() {
      now = DateTime(2026, 10, 20, 9);
      SharedPreferences.setMockInitialValues({});
    });

    test('fetches, parses and caches on a cold start', () async {
      var fetches = 0;
      final repo = OpenMeteoWeatherRepository(
        fetchJson: (uri) async {
          fetches++;
          return samplePayload();
        },
        now: () => now,
      );
      final snap = await repo.current();
      expect(snap?.temperatureC, 28.4);
      expect(fetches, 1);
      // Second call within the TTL serves the cache without fetching.
      final again = await repo.current();
      expect(again?.temperatureC, 28.4);
      expect(fetches, 1);
    });

    test('fresh cache is served without any fetch', () async {
      final seed = OpenMeteoWeatherRepository(
        fetchJson: (uri) async => samplePayload(),
        now: () => now,
      );
      await seed.current();
      var fetches = 0;
      final repo = OpenMeteoWeatherRepository(
        fetchJson: (uri) async {
          fetches++;
          throw Exception('offline');
        },
        now: () => now.add(const Duration(minutes: 10)),
      );
      final snap = await repo.current();
      expect(snap?.temperatureC, 28.4);
      expect(fetches, 0);
    });

    test('stale cache is refreshed; failure falls back to the stale value',
        () async {
      final seed = OpenMeteoWeatherRepository(
        fetchJson: (uri) async => samplePayload(),
        now: () => now,
      );
      await seed.current();
      final later = now.add(const Duration(minutes: 45));
      final failing = OpenMeteoWeatherRepository(
        fetchJson: (uri) async => throw Exception('offline'),
        now: () => later,
      );
      final snap = await failing.current();
      expect(snap?.temperatureC, 28.4);
    });

    test('no cache + fetch failure -> null (card hides)', () async {
      final repo = OpenMeteoWeatherRepository(
        fetchJson: (uri) async => throw Exception('offline'),
        now: () => now,
      );
      expect(await repo.current(), isNull);
    });
  });

  group('WeatherCard', () {
    testWidgets('renders temperature, label and extremes', (tester) async {
      final repo = _FakeWeatherRepo(WeatherSnapshot(
        temperatureC: 28.4,
        weatherCode: 80,
        tempMaxC: 33.1,
        tempMinC: 25.2,
        fetchedAt: DateTime(2026, 10, 20, 9),
      ));
      await tester
          .pumpWidget(localizedApp(home: WeatherCard(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weather_card')), findsOneWidget);
      expect(find.text('28°C · Mưa rào'), findsOneWidget);
      expect(find.textContaining('Cao nhất 33°'), findsOneWidget);
      expect(find.textContaining('Thấp nhất 25°'), findsOneWidget);
    });

    testWidgets('renders nothing when weather is unavailable', (tester) async {
      await tester.pumpWidget(
        localizedApp(home: WeatherCard(repository: _FakeWeatherRepo(null))),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('weather_card')), findsNothing);
    });
  });
}

class _FakeWeatherRepo implements WeatherRepository {
  _FakeWeatherRepo(this.value);
  final WeatherSnapshot? value;
  @override
  Future<WeatherSnapshot?> current() async => value;
}
