import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _translations = <String, Map<String, dynamic>>{};

class _LoadedTranslations extends AssetLoader {
  const _LoadedTranslations();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      _translations[locale.languageCode]!;
}

/// Load real catalogs outside widget tests' fake async zone.
Future<void> loadCameraTestTranslations() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  for (final language in ['vi', 'en']) {
    _translations[language] = jsonDecode(
            await rootBundle.loadString('assets/translations/$language.json'))
        as Map<String, dynamic>;
  }
}

Widget localizedCameraTestApp({
  String language = 'vi',
  required Widget home,
  TransitionBuilder? builder,
  GlobalKey<NavigatorState>? navigatorKey,
}) =>
    EasyLocalization(
      supportedLocales: const [Locale('vi'), Locale('en')],
      path: 'assets/translations',
      assetLoader: const _LoadedTranslations(),
      startLocale: Locale(language),
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          navigatorKey: navigatorKey,
          builder: builder,
          home: home,
        ),
      ),
    );
