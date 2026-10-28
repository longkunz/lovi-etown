import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();

  static const _vi = {
    'settings': {
      'title': 'Cài đặt',
      'language': 'Ngôn ngữ',
      'language_vietnamese': 'Tiếng Việt',
      'language_english': 'Tiếng Anh',
      'language_note': 'Áp dụng ngay, không cần khởi động lại.',
    },
  };

  static const _en = {
    'settings': {
      'title': 'Settings',
      'language': 'Language',
      'language_vietnamese': 'Vietnamese',
      'language_english': 'English',
      'language_note': 'Applies immediately, no restart needed.',
    },
  };

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      locale.languageCode == 'en' ? _en : _vi;
}

Widget _settingsApp({Locale? startLocale}) => EasyLocalization(
      supportedLocales: const [Locale('vi'), Locale('en')],
      path: 'assets/translations',
      assetLoader: const _Loader(),
      fallbackLocale: const Locale('vi'),
      // No startLocale here either: mirrors LocalizationWrapper after #52.
      startLocale: startLocale,
      saveLocale: true,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SettingsScreen(),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Mirrors main.dart: the static device locale must be initialized
    // before any EasyLocalization widget without a startLocale builds.
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('default locale follows the device locale, not a pinned vi',
      (tester) async {
    Locale? resolved;
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'assets/translations',
        assetLoader: const _Loader(),
        fallbackLocale: const Locale('vi'),
        saveLocale: false,
        child: Builder(
          builder: (context) {
            resolved = context.locale;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Whatever the test device reports, the wrapper must resolve to it
    // instead of forcing Vietnamese (compared by language code: the test
    // device reports en_US, which resolves to the supported en locale).
    expect(resolved?.languageCode,
        ui.PlatformDispatcher.instance.locale.languageCode);
    expect(resolved?.languageCode, isNot('vi'));
  });

  testWidgets('switching language applies immediately', (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    // The test device locale is English, so the Vietnamese option is
    // initially labeled "Vietnamese".
    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt'), findsOneWidget);

    // Option titles are translated too: in Vietnamese UI the English
    // option is labeled "Tiếng Anh".
    await tester.tap(find.text('Tiếng Anh'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('explicit choice persists across a fresh app start',
      (tester) async {
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt'), findsOneWidget);

    // Fresh EasyLocalization tree, same mock preferences store.
    await tester.pumpWidget(_settingsApp());
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt'), findsOneWidget);
  });
}
