import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/services/camera_api_client.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/local_favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/utils/failure.dart';

import '../../mobile/test/features/cameras/camera_api_client_test.dart'
    show MockHttpClientAdapter;
import '../../mobile/test/features/cameras/local_favorites_repository_test.dart'
    show FakeFavoritesLocalStore;
import '../../mobile/test/features/cameras/camera_preview_cubit_test.dart'
    show ControlledCameraRepository, FakePreviewClock;

void main() {
  late Dio dio;
  late MockHttpClientAdapter adapter;
  late CameraApiClient client;
  setUp(() {
    dio = Dio();
    adapter = MockHttpClientAdapter();
    dio.httpClientAdapter = adapter;
    client = CameraApiClient(
      dio: dio,
      config: const CameraConnectionConfig(
        baseUrl: 'https://example.test',
        readerKey: 'REVIEW_DUMMY',
      ),
    );
  });
  test('backend route/header/query contract', () async {
    RequestOptions? sent;
    adapter.handler = (o) {
      sent = o;
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    };
    await client.getCatalog(query: 'Pasteur');
    expect(sent!.uri.path, '/v1/cameras');
    expect(sent!.headers['x-api-key'], 'REVIEW_DUMMY');
    expect(sent!.queryParameters['provinceId'], 'tp_hcm');
    expect(sent!.queryParameters['q'], 'Pasteur');
  });
  test('backend data/meta envelope yields camera', () async {
    adapter.handler = (o) => ResponseBody.fromString(
      '{"data":[{"id":"00000000-0000-0000-0000-000000000001","name":"Pasteur","capabilities":{"snapshot":true}}],"meta":{"dataMode":"fixture","page":{"limit":50,"offset":0,"total":1},"catalog":{"version":"new"}}}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
    final r = await client.getCatalog();
    expect(
      r.getOrElse((_) => throw StateError('parse failed')).items.length,
      1,
    );
  });
  test('different scheme/port must be rejected without sending', () async {
    var sent = false;
    adapter.handler = (o) {
      sent = true;
      return ResponseBody.fromString('', 304);
    };
    await client.getSnapshot('http://example.test:8443/steal');
    expect(sent, false);
  });
  test('authenticated snapshot must disable redirects', () async {
    RequestOptions? sent;
    adapter.handler = (o) {
      sent = o;
      return ResponseBody.fromString('', 304);
    };
    await client.getSnapshot('/v1/cameras/id/snapshot');
    expect(sent!.followRedirects, false);
  });
  test('429 must retain retryable and Retry-After', () async {
    adapter.handler = (o) => ResponseBody.fromString(
      '{}',
      429,
      headers: {
        'retry-after': ['120'],
      },
    );
    final r = await client.getSnapshot('/v1/cameras/id/snapshot');
    final f = r.fold(
      (f) => f,
      (_) => throw StateError('missing error'),
    ) as ApiFailure;
    expect(f.retryable, true);
    expect(f.retryAfter, const Duration(seconds: 120));
  });
  test('four-byte fake JPEG must not become frame', () async {
    adapter.handler = (o) => ResponseBody(
      Stream.value(Uint8List.fromList([255, 216, 0, 0])),
      200,
      headers: {
        'content-type': ['image/jpeg'],
      },
    );
    final r = await client.getSnapshot('/v1/cameras/id/snapshot');
    expect(r.isLeft(), true);
  });
  test('concurrent favorite additions preserve both IDs', () async {
    final store = FakeFavoritesLocalStore();
    final repo = LocalFavoritesRepository(store: store);
    await repo.load();
    const a = Camera(
      id: 'A',
      name: 'A',
      provinceId: 'tp_hcm',
      playbackEndpoint: '/A',
    );
    const b = Camera(
      id: 'B',
      name: 'B',
      provinceId: 'tp_hcm',
      playbackEndpoint: '/B',
    );
    await Future.wait([repo.setSaved(a, true), repo.setSaved(b, true)]);
    expect((await repo.watch().first).map((x) => x.id).toSet(), {'A', 'B'});
    repo.dispose();
  });
  test('switch camera must never reuse previous descriptor', () async {
    final repo = ControlledCameraRepository();
    final clock = FakePreviewClock();
    final c = CameraPreviewCubit(repository: repo, clock: clock);
    final endpoints = <String>[];
    repo.onSnapshot = (endpoint, etag, token) async {
      endpoints.add(endpoint);
      return Right(
        SnapshotReceived(
          SnapshotFrame(bytes: Uint8List.fromList([255, 216, 0, 0])),
        ),
      );
    };
    await c.open('A');
    repo.onPlayback = (id, token) async =>
        const Left(ApiFailure('temporary', statusCode: 503, retryable: true));
    await c.open('B');
    expect(endpoints.last, contains('/B/'));
    await c.close();
  });
  test('304 preserves original fetchedAt', () async {
    final repo = ControlledCameraRepository();
    final clock = FakePreviewClock();
    final c = CameraPreviewCubit(repository: repo, clock: clock);
    await c.open('A');
    final old = c.state.currentFrame!.fetchedAt;
    repo.onSnapshot = (endpoint, etag, token) async =>
        const Right(SnapshotUnchanged());
    clock.currentTime = clock.currentTime.add(const Duration(minutes: 2));
    await c.retry();
    expect(c.state.currentFrame!.fetchedAt, old);
    await c.close();
  });
  test('background epoch rejects late pre-background success', () async {
    final repo = ControlledCameraRepository();
    final clock = FakePreviewClock();
    final c = CameraPreviewCubit(repository: repo, clock: clock);
    final pending = <Completer<Either<Failure, SnapshotReply>>>[];
    repo.onSnapshot = (endpoint, etag, token) {
      final p = Completer<Either<Failure, SnapshotReply>>();
      pending.add(p);
      return p.future;
    };
    final opening = c.open('A');
    await Future<void>.delayed(Duration.zero);
    expect(pending.length, 1);
    c.setForeground(false);
    c.setForeground(true);
    expect(pending.length, 2);
    pending[1].complete(
      Right(SnapshotReceived(SnapshotFrame(bytes: Uint8List.fromList([2])))),
    );
    await Future<void>.delayed(Duration.zero);
    pending[0].complete(
      Right(SnapshotReceived(SnapshotFrame(bytes: Uint8List.fromList([1])))),
    );
    await opening;
    expect(c.state.currentFrame!.bytes, [2]);
    await c.close();
  });
}
