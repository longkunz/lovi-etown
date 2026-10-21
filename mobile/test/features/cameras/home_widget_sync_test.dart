import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/features/cameras/data/widget/home_widget_sync_service.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class _Sink implements WidgetDataSink {
  final Map<String, String> saved = {};
  var updates = 0;
  @override
  Future<void> save(String key, String value) async => saved[key] = value;
  @override
  Future<void> requestUpdate() async => updates++;
}

class _Repo implements CameraRepository {
  _Repo({this.failSnapshot = false});
  final bool failSnapshot;

  static const camera = Camera(
    id: 'fav-1',
    name: 'Mai Chí Thọ - Lương Định Của',
    provinceId: 'tp_hcm',
    snapshotCapable: true,
    playbackEndpoint: '/v1/cameras/fav-1/playback',
    snapshotEndpoint: '/v1/cameras/fav-1/snapshot',
  );

  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      const Right(camera);

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
      {String? etag, CancelToken? cancelToken}) async {
    if (failSnapshot) return const Left(ServerFailure('boom'));
    return Right(SnapshotReceived(SnapshotFrame(
      bytes: Uint8List.fromList(const [1, 2, 3, 4]),
      etag: 'e1',
    )));
  }

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      const Right(CatalogPage(
          items: [], limit: 50, offset: 0, total: 0, catalogVersion: 'v1', dataMode: 'fixture'));

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async =>
      const Right(PlaybackDescriptor(
        cameraId: 'fav-1',
        kind: 'snapshot_poll',
        snapshotEndpoint: '/v1/cameras/fav-1/snapshot',
        refreshIntervalMs: 60000,
      ));
}

FavoriteCamera fav(String id) =>
    FavoriteCamera(id: id, name: 'Cam $id', addedAt: DateTime(2026, 10, 20));

void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lovi_widget_test');
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  HomeWidgetSyncService service(_Repo repo, _Sink sink) => HomeWidgetSyncService(
        repository: repo,
        sink: sink,
        filesDir: () async => tempDir,
        now: () => DateTime(2026, 10, 20, 14, 5),
      );

  test('syncs the first favorite: image file + name + time + update', () async {
    final sink = _Sink();
    await service(_Repo(), sink).sync([fav('fav-1'), fav('fav-2')]);

    expect(sink.saved['cameraName'], 'Mai Chí Thọ - Lương Định Của');
    expect(sink.saved['updatedAt'], '14:05');
    final imagePath = sink.saved['imagePath'];
    expect(imagePath, isNotNull);
    expect(imagePath, endsWith(HomeWidgetSyncService.snapshotFileName));
    final written = await File(imagePath!).readAsBytes();
    expect(written, [1, 2, 3, 4]);
    expect(sink.updates, 1);
  });

  test('empty favorites clear the widget data', () async {
    final sink = _Sink();
    await service(_Repo(), sink).sync(const []);
    expect(sink.saved['cameraName'], '');
    expect(sink.saved['imagePath'], '');
    expect(sink.updates, 1);
  });

  test('snapshot failure is swallowed and saves nothing', () async {
    final sink = _Sink();
    await service(_Repo(failSnapshot: true), sink).sync([fav('fav-1')]);
    expect(sink.saved, isEmpty);
    expect(sink.updates, 0);
  });
}
