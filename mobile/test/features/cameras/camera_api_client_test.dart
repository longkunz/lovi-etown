import 'dart:convert';
import 'dart:io';
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

    // T01: payloads with a valid image header / magic bytes that cannot be
    // decoded must be rejected here, before they can reach the preview,
    // the viewer or the shared snapshot cache as a "good" frame.
    group('snapshot_decode_validation_T01', () {
      void serveBytes(Uint8List bytes, {String contentType = 'image/jpeg'}) {
        adapter.handler = (options) {
          return ResponseBody(
            Stream.value(bytes),
            200,
            headers: {
              Headers.contentTypeHeader: [contentType],
            },
          );
        };
      }

      // SOI + APP0/JFIF header, then EOI immediately: header checks pass,
      // but there is no frame to decode.
      Uint8List corruptJpeg() {
        final bytes = Uint8List(256);
        bytes[0] = 0xFF;
        bytes[1] = 0xD8; // SOI
        bytes[2] = 0xFF;
        bytes[3] = 0xE0; // APP0
        bytes[4] = 0x00;
        bytes[5] = 0x10; // APP0 length
        bytes.setRange(6, 11, [0x4A, 0x46, 0x49, 0x46, 0x00]); // JFIF\0
        bytes[20] = 0xFF;
        bytes[21] = 0xD9; // EOI, no SOF/SOS data at all
        return bytes;
      }

      // PNG signature + IHDR header with a bogus CRC and no IDAT/IEND.
      Uint8List corruptPng() {
        final bytes = Uint8List(256);
        bytes.setRange(
            0, 8, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        bytes.setRange(8, 12, [0x00, 0x00, 0x00, 0x0D]); // IHDR length
        bytes.setRange(12, 16, [0x49, 0x48, 0x44, 0x52]); // 'IHDR'
        bytes.setRange(16, 20, [0x00, 0x00, 0x00, 0x10]); // width 16
        bytes.setRange(20, 24, [0x00, 0x00, 0x00, 0x10]); // height 16
        bytes[24] = 0x08; // bit depth
        bytes[25] = 0x02; // colour type RGB
        return bytes;
      }

      // RIFF/WEBP header + VP8L chunk whose signature byte is not 0x2F.
      Uint8List corruptWebp() {
        final bytes = Uint8List(256);
        bytes.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]); // 'RIFF'
        bytes.setRange(4, 8, [0xF8, 0x00, 0x00, 0x00]); // RIFF size
        bytes.setRange(8, 12, [0x57, 0x45, 0x42, 0x50]); // 'WEBP'
        bytes.setRange(12, 16, [0x56, 0x50, 0x38, 0x4C]); // 'VP8L'
        bytes.setRange(16, 20, [0xEC, 0x00, 0x00, 0x00]); // chunk size
        bytes[20] = 0x00; // invalid VP8L signature (must be 0x2F)
        return bytes;
      }

      test('valid_jpeg_is_accepted', () async {
        final jpegBytes =
            await File('assets/fixtures/snapshots/sample1.jpg').readAsBytes();
        serveBytes(jpegBytes);

        final result =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');

        expect(result.isRight(), isTrue);
        final reply = result.getOrElse((_) => throw Exception());
        expect(reply, isA<SnapshotReceived>());
        expect((reply as SnapshotReceived).frame.bytes, equals(jpegBytes));
      });

      test('valid_png_is_accepted', () async {
        final pngBytes = base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGMUqTjBQApgIkn1qIZRDUNKAwBCMAF0/IRNbQAAAABJRU5ErkJggg==');
        serveBytes(pngBytes, contentType: 'image/png');

        final result =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');

        expect(result.isRight(), isTrue);
        final reply = result.getOrElse((_) => throw Exception());
        expect(reply, isA<SnapshotReceived>());
      });

      test('valid_webp_is_accepted', () async {
        final webpBytes = base64Decode(
            'UklGRjoAAABXRUJQVlA4IC4AAAAQAgCdASoQABAAAUAmJaACdLoB+AH4AAPIAP7udn/+oLQ18vxov/U4MHPn4/wA');
        serveBytes(webpBytes, contentType: 'image/webp');

        final result =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');

        expect(result.isRight(), isTrue);
        final reply = result.getOrElse((_) => throw Exception());
        expect(reply, isA<SnapshotReceived>());
      });

      test('undecodable_jpeg_with_valid_header_is_rejected', () async {
        serveBytes(corruptJpeg());

        final result =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');

        expect(result.isLeft(), isTrue);
        final failure = result.fold((f) => f, (_) => throw Exception());
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).statusCode, equals(422));
      });

      test('undecodable_png_with_valid_signature_is_rejected', () async {
        serveBytes(corruptPng(), contentType: 'image/png');

        final result =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');

        expect(result.isLeft(), isTrue);
        final failure = result.fold((f) => f, (_) => throw Exception());
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).statusCode, equals(422));
      });

      test('undecodable_webp_with_valid_header_is_rejected', () async {
        serveBytes(corruptWebp(), contentType: 'image/webp');

        final result =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');

        expect(result.isLeft(), isTrue);
        final failure = result.fold((f) => f, (_) => throw Exception());
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).statusCode, equals(422));
      });

      test('undecodable_frame_after_valid_frame_is_rejected', () async {
        final jpegBytes =
            await File('assets/fixtures/snapshots/sample1.jpg').readAsBytes();

        serveBytes(jpegBytes);
        final first =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');
        expect(first.isRight(), isTrue);

        serveBytes(corruptJpeg());
        final second =
            await client.getSnapshot('/api/v1/cameras/cam-1/snapshot');
        expect(second.isLeft(), isTrue);
      });
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
