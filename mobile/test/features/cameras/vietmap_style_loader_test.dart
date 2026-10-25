import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/vietmap_style_loader.dart';

class StyleAdapter implements HttpClientAdapter {
  RequestOptions? request;
  int status = 200;
  String body = '{"version":8,"sources":{},"layers":[]}';
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('style HTTP has no backend key and sanitizes authorization failures',
      () async {
    final adapter = StyleAdapter();
    final loader =
        VietmapStyleLoader(client: Dio()..httpClientAdapter = adapter);
    await loader.load('tm', 'secret map key');
    expect(adapter.request!.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('x-api-key')));
    expect(adapter.request!.uri.host, 'maps.vietmap.vn');
    expect(adapter.request!.uri.queryParameters['apikey'], 'secret map key');
    adapter.status = 403;
    try {
      await loader.load('tf', 'secret map key');
      fail('must fail');
    } on VietmapStyleFailure catch (error) {
      expect(error.kind, VietmapStyleFailureKind.unauthorized);
      expect(error.toString(), isNot(contains('secret')));
      expect(error.toString(), isNot(contains('https')));
    }
  });

  test(
      'traffic merges sources and layers without replacing base or duplicate ids',
      () {
    final base = <String, dynamic>{
      'version': 8,
      'sources': {'base': <String, dynamic>{}},
      'layers': [
        {'id': 'base'}
      ]
    };
    final overlay = <String, dynamic>{
      'sources': {'traffic': <String, dynamic>{}},
      'layers': [
        {'id': 'traffic'}
      ]
    };
    final merged = VietmapStyleLoader.mergeTraffic(base, overlay);
    expect((merged['sources'] as Map).keys, containsAll(['base', 'traffic']));
    expect(
        (VietmapStyleLoader.mergeTraffic(merged, overlay)['layers'] as List)
            .length,
        2);
  });
  test('refuses non Vietmap resource hosts', () {
    expect(
        () => VietmapStyleLoader.validateResources({
              'sources': {
                'bad': {'url': 'https://evil.example/a'}
              }
            }),
        throwsA(isA<VietmapStyleFailure>()));
  });
  test('malformed successful traffic payload becomes a typed safe failure',
      () async {
    final adapter = StyleAdapter();
    final loader =
        VietmapStyleLoader(client: Dio()..httpClientAdapter = adapter);
    for (final body in [
      '{"sources":{},"layers":[{}]}',
      '{"sources":{},"layers":[1]}',
      '{"sources":{"bad":1},"layers":[]}'
    ]) {
      adapter.body = body;
      await expectLater(
          loader.load('tf', 'private-key'),
          throwsA(isA<VietmapStyleFailure>().having(
              (e) => e.kind, 'kind', VietmapStyleFailureKind.malformed)));
    }
    expect(
        () => VietmapStyleLoader.mergeTraffic({
              'sources': <String, dynamic>{},
              'layers': <Object?>[]
            }, {
              'sources': <String, dynamic>{},
              'layers': <Object?>[<String, dynamic>{}]
            }),
        throwsA(isA<VietmapStyleFailure>()));
    loader.dispose();
  });
}
