import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/config/map_config.dart';

void main() {
  test('runtime environment supplies the map key', () {
    dotenv.loadFromString(envString: 'VIETMAP_API_KEY=environment_key');
    expect(MapConnectionConfig.fromEnvironment().apiKey, 'environment_key');
  });

  test('map key requires non whitespace content', () {
    expect(const MapConnectionConfig().isConfigured, false);
    expect(const MapConnectionConfig(apiKey: '  ').isConfigured, false);
    expect(const MapConnectionConfig(apiKey: ' key ').isConfigured, true);
  });
}
