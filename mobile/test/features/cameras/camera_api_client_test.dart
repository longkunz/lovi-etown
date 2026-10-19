import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/services/camera_api_client.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/utils/failure.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  late ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CameraApiClient', () {
    late Dio dio;
    late MockHttpClientAdapter adapter;
    late CameraApiClient client;

    const testConfig = CameraConnectionConfig(
      baseUrl: 'https://api.ttgt.tphcm.gov.vn',
      readerKey: 'secret_reader_key_123',
    );

    setUp(() {
      dio = Dio();
      adapter = MockHttpClientAdapter();
      dio.httpClientAdapter = adapter;
      client = CameraApiClient(dio: dio, config: testConfig);
    });

    test('getCatalog_sends_reader_key_and_correct_params', () async {
      adapter.handler = (options) {
        expect(options.uri.path, equals('/v1/cameras'));
        expect(options.headers['x-api-key'], equals('secret_reader_key_123'));
        expect(options.queryParameters['limit'], equals(50));
        expect(options.queryParameters['offset'], equals(10));
        expect(options.queryParameters['q'], equals('Pasteur'));
        expect(options.queryParameters['provinceId'], equals('tp_hcm'));
        expect(options.queryParameters['district'], equals('Quan 1'));

        const responseJson = '''
        {
          "data": [
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "Pasteur - Le Loi",
              "provinceId": "tp_hcm",
              "district": "Quan 1",
              "capabilities": { "snapshot": true },
              "playbackEndpoint": "/v1/cameras/00000000-0000-0000-0000-000000000001/playback"
            }
          ],
          "meta": {
            "page": {
              "limit": 50,
              "offset": 10,
              "total": 100
            },
            "catalog": {
              "version": "v1"
            }
          }
        }
        ''';

        return ResponseBody.fromString(
          responseJson,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final result = await client.getCatalog(
        query: 'Pasteur',
        district: 'Quan 1',
        limit: 50,
        offset: 10,
      );

      expect(result.isRight(), isTrue);
      final page = result.getOrElse((_) => throw Exception());
      expect(page.items.length, equals(1));
      expect(page.items.first.name, equals('Pasteur - Le Loi'));
      expect(page.total, equals(100));
    });

    test('snapshot_rejects_cross_origin_or_absolute_urls', () async {
      final res1 =
          await client.getSnapshot('https://malicious.attacker.com/steal-key');
      expect(res1.isLeft(), isTrue);
      final failure1 = res1.fold((f) => f, (_) => throw Exception());
      expect(failure1, isA<ApiFailure>());

      final res2 = await client.getSnapshot('http://localhost:9999/other');
      expect(res2.isLeft(), isTrue);
    });

    test('snapshot_returns_SnapshotUnchanged_on_304', () async {
      adapter.handler = (options) {
        expect(options.headers['If-None-Match'], equals('etag-test-123'));
        return ResponseBody.fromString('', 304);
      };

      final result = await client.getSnapshot(
        '/api/v1/cameras/cam-1/snapshot',
        etag: 'etag-test-123',
      );

      expect(result.isRight(), isTrue);
      final reply = result.getOrElse((_) => throw Exception());
      expect(reply, isA<SnapshotUnchanged>());
    });

    test('snapshot_rejects_stream_exceeding_2MiB', () async {
      adapter.handler = (options) {
        // Stream greater than 2 MiB (e.g. 2.1 MiB)
        final bigChunk = Uint8List(2 * 1024 * 1024 + 1024);
        return ResponseBody(
          Stream.value(bigChunk),
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg'],
          },
        );
      };

      final result = await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');
      expect(result.isLeft(), isTrue);
      final failure = result.fold((f) => f, (_) => throw Exception());
      expect(failure.message, contains('2 MiB'));
    });

    test('missing_config_returns_failure_without_sending_request', () async {
      var requestMade = false;
      adapter.handler = (options) {
        requestMade = true;
        return ResponseBody.fromString('{}', 200);
      };

      final unconfiguredClient = CameraApiClient(
        dio: dio,
        config: const CameraConnectionConfig(baseUrl: '', readerKey: ''),
      );

      final result = await unconfiguredClient.getCatalog();
      expect(result.isLeft(), isTrue);
      expect(requestMade, isFalse);
    });
  });
}
