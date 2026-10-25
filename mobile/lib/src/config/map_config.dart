import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapConnectionConfig {
  final String apiKey;
  const MapConnectionConfig({this.apiKey = ''});
  factory MapConnectionConfig.fromEnvironment() {
    final env = dotenv.isInitialized ? dotenv.env : const <String, String>{};
    return MapConnectionConfig(
        apiKey: const bool.hasEnvironment('VIETMAP_API_KEY')
            ? const String.fromEnvironment('VIETMAP_API_KEY')
            : env['VIETMAP_API_KEY'] ?? '');
  }
  bool get isConfigured => apiKey.trim().isNotEmpty;
}
