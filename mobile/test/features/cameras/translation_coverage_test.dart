import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the i18n migration (issue #51): every key the camera/map UI
/// references through `.tr()` must exist in both translation files, and
/// interpolated placeholders must match between locales — otherwise
/// switching to English leaks Vietnamese (or crashes interpolation).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const newCameraKeys = [
    'reset_failed',
    'favorites_update_failed',
    'reset',
    'load_failed',
    'live',
    'snapshot',
    'snapshot_static',
    'snapshot_load_failed',
    'directions',
    'grid_title',
    'multi_empty',
    'back',
    'fullscreen',
    'favorite',
    'unfavorite',
    'view_grid_tooltip',
    'close',
    'clear_search',
  ];

  Future<Map<String, dynamic>> loadTranslations(String locale) async {
    final raw =
        await rootBundle.loadString('assets/translations/$locale.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  int placeholderCount(String value) =>
      RegExp(r'\{\}').allMatches(value).length;

  test('new camera keys exist in both locales with matching placeholders',
      () async {
    final en = await loadTranslations('en');
    final vi = await loadTranslations('vi');
    final enCamera = en['camera'] as Map<String, dynamic>;
    final viCamera = vi['camera'] as Map<String, dynamic>;
    for (final key in newCameraKeys) {
      expect(enCamera.containsKey(key), isTrue, reason: 'en camera.$key');
      expect(viCamera.containsKey(key), isTrue, reason: 'vi camera.$key');
      expect(
        placeholderCount(enCamera[key] as String),
        placeholderCount(viCamera[key] as String),
        reason: 'placeholder mismatch for camera.$key',
      );
    }
  });

  test('map_discovery keys exist in both locales', () async {
    final en = await loadTranslations('en');
    final vi = await loadTranslations('vi');
    final enMap = en['map_discovery'] as Map<String, dynamic>;
    final viMap = vi['map_discovery'] as Map<String, dynamic>;
    expect(enMap.isNotEmpty, isTrue);
    for (final key in viMap.keys) {
      expect(enMap.containsKey(key), isTrue, reason: 'en map_discovery.$key');
    }
    for (final key in enMap.keys) {
      expect(viMap.containsKey(key), isTrue, reason: 'vi map_discovery.$key');
    }
  });
}
