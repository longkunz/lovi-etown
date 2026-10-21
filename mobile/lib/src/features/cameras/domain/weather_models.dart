import 'package:equatable/equatable.dart';

/// Current-weather snapshot for the catalog header card (T11, part 2).
/// Source: Open-Meteo (no API key). Display-only; never blocks the catalog.
class WeatherSnapshot extends Equatable {
  final double temperatureC;
  final int weatherCode;
  final double? tempMaxC;
  final double? tempMinC;
  final DateTime fetchedAt;

  const WeatherSnapshot({
    required this.temperatureC,
    required this.weatherCode,
    this.tempMaxC,
    this.tempMinC,
    required this.fetchedAt,
  });

  String get conditionLabel => weatherCodeLabel(weatherCode);

  Map<String, dynamic> toJson() => {
        'temperatureC': temperatureC,
        'weatherCode': weatherCode,
        'tempMaxC': tempMaxC,
        'tempMinC': tempMinC,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      temperatureC: (json['temperatureC'] as num).toDouble(),
      weatherCode: (json['weatherCode'] as num).toInt(),
      tempMaxC: (json['tempMaxC'] as num?)?.toDouble(),
      tempMinC: (json['tempMinC'] as num?)?.toDouble(),
      fetchedAt:
          DateTime.tryParse(json['fetchedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [temperatureC, weatherCode, tempMaxC, tempMinC, fetchedAt];
}

/// WMO weather-code → Vietnamese label (Open-Meteo uses WMO codes).
String weatherCodeLabel(int code) {
  return switch (code) {
    0 => 'Trời quang',
    1 || 2 => 'Có mây',
    3 => 'Nhiều mây',
    45 || 48 => 'Sương mù',
    51 || 53 || 55 || 56 || 57 => 'Mưa phùn',
    61 || 63 || 65 || 66 || 67 => 'Mưa',
    71 || 73 || 75 || 77 => 'Tuyết',
    80 || 81 || 82 => 'Mưa rào',
    85 || 86 => 'Mưa tuyết',
    95 || 96 || 99 => 'Dông',
    _ => 'Không rõ',
  };
}

/// Whether the WMO code means precipitation (rain/drizzle/showers/storm).
bool weatherCodeIsWet(int code) =>
    (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;
