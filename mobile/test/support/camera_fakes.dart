import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class InMemoryFavoritesRepository implements FavoritesRepository {
  final _controller = StreamController<List<FavoriteCamera>>.broadcast();
  final Map<String, FavoriteCamera> _saved = {};

  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield _saved.values.toList();
    yield* _controller.stream;
  }

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async {
    if (saved) {
      _saved[camera.id] = FavoriteCamera(
        id: camera.id,
        name: camera.name,
        district: camera.district,
        addedAt: DateTime.now(),
      );
    } else {
      _saved.remove(camera.id);
    }
    _controller.add(_saved.values.toList());
    return const Right(null);
  }

  @override
  FutureEither<List<FavoriteCamera>> load() async {
    return Right(_saved.values.toList());
  }

  @override
  FutureEither<void> resetCorruptData() async {
    _saved.clear();
    _controller.add([]);
    return const Right(null);
  }

  void dispose() {
    _controller.close();
  }
}

class FakeIntegrationCameraRepository implements CameraRepository {
  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  FakeIntegrationCameraRepository({List<Camera>? items})
      : _items = items ?? _defaultItems;

  final List<Camera> _items;

  static final List<Camera> _defaultItems = List.generate(
    20,
    (index) => Camera(
      id: 'cam-uuid-$index',
      name: 'Camera Giao Thông $index - Nguyen Hue',
      provinceId: 'tp_hcm',
      district: index.isEven ? 'Quan 1' : 'Quan 3',
      address: 'Đường Nguyễn Huệ số $index',
      snapshotCapable: true,
      snapshotEndpoint: '/api/v1/cameras/cam-uuid-$index/snapshot',
      playbackEndpoint: '/api/v1/cameras/cam-uuid-$index/playback',
      thumbnailEndpoint: 'assets/fixtures/snapshots/sample_camera_1.jpg',
    ),
  );

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    var filtered = _items;
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered =
          filtered.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    if (district != null && district.trim().isNotEmpty) {
      filtered = filtered.where((c) => c.district == district).toList();
    }

    final paged = filtered.skip(offset).take(limit).toList();
    return Right(CatalogPage(
      items: paged,
      limit: limit,
      offset: offset,
      total: filtered.length,
      catalogVersion: 'v1',
    ));
  }

  @override
  FutureEither<List<DistrictOption>> districts(
      {CancelToken? cancelToken}) async {
    return const Right([
      DistrictOption(name: 'Quan 1', count: 10),
      DistrictOption(name: 'Quan 3', count: 10),
    ]);
  }

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async {
    final found = _items.firstWhere(
      (c) => c.id == id,
      orElse: () => _items.first,
    );
    return Right(found);
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
      {CancelToken? cancelToken}) async {
    return Right(PlaybackDescriptor(
      cameraId: id,
      kind: 'snapshot',
      snapshotEndpoint: '/api/v1/cameras/$id/snapshot',
      refreshIntervalMs: 12000,
    ));
  }

  @override
  FutureEither<SnapshotReply> snapshot(
    String endpoint, {
    String? etag,
    CancelToken? cancelToken,
  }) async {
    return Right(SnapshotReceived(SnapshotFrame(
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
      etag: 'etag-1',
      fetchedAt: DateTime.now(),
    )));
  }
}
