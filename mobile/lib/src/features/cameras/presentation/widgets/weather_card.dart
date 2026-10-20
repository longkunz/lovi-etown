import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/data/open_meteo_weather_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/weather_repository.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Header weather card for the catalog screen (T11, part 2).
/// Loads once on mount; renders nothing while loading or when the weather
/// is unavailable, so it can never block or break the camera list.
class WeatherCard extends StatefulWidget {
  const WeatherCard({this.repository, super.key});

  /// Injectable for tests; defaults to the Open-Meteo repository.
  final WeatherRepository? repository;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.repository ?? OpenMeteoWeatherRepository();
    final result = await repo.current();
    if (mounted) {
      setState(() => _snapshot = result);
    }
  }

  IconData get _icon {
    final code = _snapshot?.weatherCode ?? 0;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code == 1 || code == 2) return Icons.wb_cloudy_outlined;
    if (code >= 95) return Icons.thunderstorm_outlined;
    if (weatherCodeIsWet(code)) return Icons.umbrella_outlined;
    return Icons.cloud_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final temp = snapshot.temperatureC.round();
    final extremes = [
      if (snapshot.tempMaxC != null) 'Cao nhất ${snapshot.tempMaxC!.round()}°',
      if (snapshot.tempMinC != null) 'Thấp nhất ${snapshot.tempMinC!.round()}°',
    ].join(' · ');

    return Container(
      key: const ValueKey('weather_card'),
      margin: const EdgeInsets.fromLTRB(
        CameraUiTokens.spacing16,
        CameraUiTokens.spacing8,
        CameraUiTokens.spacing16,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing12,
        vertical: CameraUiTokens.spacing8,
      ),
      decoration: BoxDecoration(
        color: CameraUiTokens.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
        border: Border.all(
          color: CameraUiTokens.primaryTeal.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(_icon, color: CameraUiTokens.primaryTeal, size: 28),
          const SizedBox(width: CameraUiTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$temp°C · ${snapshot.conditionLabel}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  extremes.isEmpty ? 'TP. Hồ Chí Minh' : 'TP. Hồ Chí Minh · $extremes',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
