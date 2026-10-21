import 'package:flutter_starter/src/features/cameras/domain/weather_models.dart';

/// Supplies the current-weather snapshot for the catalog header card.
/// Returns null when weather is unavailable — the card hides itself and
/// the catalog is never blocked by a weather failure (T11).
abstract class WeatherRepository {
  Future<WeatherSnapshot?> current();
}
