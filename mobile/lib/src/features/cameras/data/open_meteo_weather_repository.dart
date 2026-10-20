import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_repository.dart';

/// Open-Meteo backed [WeatherRepository] for central Ho Chi Minh City
/// (T11). No API key required. Results are cached in SharedPreferences for
/// [ttl]; a failed refresh falls back to the stale cache, and a total miss
/// returns null so the card hides instead of erroring.
class OpenMeteoWeatherRepository implements WeatherRepository {
  static const cacheKey = 'weather_hcmc_v1';
  static const ttl = Duration(minutes: 30);

  // Central HCMC (District 1) — the catalog's home area for the trial.
  static const latitude = 10.7769;
  static const longitude = 106.7009;

  final Future<Map<String, dynamic>> Function(Uri uri) _fetchJson;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;

  OpenMeteoWeatherRepository({
    Future<Map<String, dynamic>> Function(Uri uri)? fetchJson,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
  })  : _fetchJson = fetchJson ?? _defaultFetch,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  static Uri forecastUri() {
    return Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m,weather_code',
      'daily': 'temperature_2m_max,temperature_2m_min',
      'timezone': 'Asia/Bangkok',
      'forecast_days': '1',
    });
  }

  static Future<Map<String, dynamic>> _defaultFetch(Uri uri) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    final response = await dio.getUri<Map<String, dynamic>>(uri);
    return response.data ?? const {};
  }

  @override
  Future<WeatherSnapshot?> current() async {
    final cached = await _readCache();
    if (cached != null && _now().difference(cached.fetchedAt) < ttl) {
      return cached;
    }
    try {
      final json = await _fetchJson(forecastUri());
      final fresh = parseForecast(json, fetchedAt: _now());
      if (fresh != null) {
        await _writeCache(fresh);
        return fresh;
      }
    } catch (_) {
      // Weather is decorative — fall through to the stale cache / null.
    }
    return cached;
  }

  /// Parses an Open-Meteo forecast payload; null when the shape is off.
  static WeatherSnapshot? parseForecast(
    Map<String, dynamic> json, {
    required DateTime fetchedAt,
  }) {
    final current = json['current'] as Map<String, dynamic>?;
    final temperature = (current?['temperature_2m'] as num?)?.toDouble();
    final code = (current?['weather_code'] as num?)?.toInt();
    if (temperature == null || code == null) return null;
    final daily = json['daily'] as Map<String, dynamic>?;
    final maxList = daily?['temperature_2m_max'] as List<dynamic>?;
    final minList = daily?['temperature_2m_min'] as List<dynamic>?;
    return WeatherSnapshot(
      temperatureC: temperature,
      weatherCode: code,
      tempMaxC: (maxList != null && maxList.isNotEmpty)
          ? (maxList.first as num?)?.toDouble()
          : null,
      tempMinC: (minList != null && minList.isNotEmpty)
          ? (minList.first as num?)?.toDouble()
          : null,
      fetchedAt: fetchedAt,
    );
  }

  Future<WeatherSnapshot?> _readCache() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(cacheKey);
      if (raw == null) return null;
      return WeatherSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(WeatherSnapshot snapshot) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(cacheKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Cache write failure is non-fatal for a decorative card.
    }
  }
}
