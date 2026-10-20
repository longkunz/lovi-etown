import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../utils/failure.dart';
import '../../../../utils/typedefs.dart';
import '../../domain/camera_models.dart';
import '../../domain/camera_repository.dart';

/// Repository serving camera catalog and snapshots from local bundled fixtures.
/// Used for demo mode and offline testing without live backend.
class FixtureCameraRepository implements CameraRepository {
  final AssetBundle bundle;
  final String fixturePath;

  List<Camera>? _cachedCameras;
  String _catalogVersion = 'fixture-v1';
  String _dataMode = 'fixture';

  FixtureCameraRepository({
    AssetBundle? bundle,
    this.fixturePath = 'assets/fixtures/cameras.json',
  }) : bundle = bundle ?? rootBundle;

  Future<List<Camera>> _loadCameras() async {
    if (_cachedCameras != null) return _cachedCameras!;

    try {
      final jsonString = await bundle.loadString(fixturePath);
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      _catalogVersion = jsonMap['catalogVersion'] as String? ?? 'fixture-v1';
      _dataMode = jsonMap['dataMode'] as String? ?? 'fixture';

      final itemsRaw = jsonMap['items'] as List<dynamic>? ?? [];
      _cachedCameras = itemsRaw.map((item) {
        final map = item as Map<String, dynamic>;
        final location = map['location'] as Map<String, dynamic>?;
        return Camera(
          id: map['id'] as String,
          name: map['name'] as String,
          provinceId: map['provinceId'] as String? ?? 'tp_hcm',
          district: map['district'] as String?,
          address: map['address'] as String?,
          snapshotCapable: map['snapshotCapable'] as bool? ?? true,
          thumbnailEndpoint: map['thumbnailEndpoint'] as String?,
          snapshotEndpoint: map['snapshotEndpoint'] as String?,
          playbackEndpoint: map['playbackEndpoint'] as String? ?? '',
          latitude: (location?['lat'] as num?)?.toDouble(),
          longitude: (location?['lng'] as num?)?.toDouble(),
        );
      }).toList();

      return _cachedCameras!;
    } catch (e) {
      return [];
    }
  }

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final all = await _loadCameras();

    var filtered = all;
    if (district != null && district.trim().isNotEmpty) {
      filtered = filtered.where((c) => c.district == district).toList();
    }

    if (query != null && query.trim().length >= 2) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((c) {
        final matchName = c.name.toLowerCase().contains(q);
        final matchAddress = c.address?.toLowerCase().contains(q) ?? false;
        return matchName || matchAddress;
      }).toList();
    }

    final total = filtered.length;
    final startIndex = offset < total ? offset : total;
    final endIndex = (startIndex + limit) < total ? (startIndex + limit) : total;
    final items = filtered.sublist(startIndex, endIndex);

    return Right(CatalogPage(
      items: items,
      limit: limit,
      offset: offset,
      total: total,
      catalogVersion: _catalogVersion,
      fetchedAt: DateTime.now(),
      isStale: false,
      dataMode: _dataMode,
    ));
  }

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async {
    final all = await _loadCameras();
    final counts = <String, int>{};

    for (final cam in all) {
      final d = cam.district;
      if (d != null && d.trim().isNotEmpty) {
        counts[d] = (counts[d] ?? 0) + 1;
      }
    }

    final list = counts.entries
        .map((e) => DistrictOption(name: e.key, count: e.value))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));

    return Right(list);
  }

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async {
    final all = await _loadCameras();
    try {
      final camera = all.firstWhere((c) => c.id == id);
      return Right(camera);
    } catch (_) {
      return Left(ServerFailure('Không tìm thấy camera $id'));
    }
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async {
    final all = await _loadCameras();
    try {
      final camera = all.firstWhere((c) => c.id == id);
      return Right(PlaybackDescriptor(
        cameraId: id,
        kind: 'snapshot',
        snapshotEndpoint: camera.snapshotEndpoint ?? '',
        refreshIntervalMs: 12000,
        capturedAt: DateTime.now(),
      ));
    } catch (_) {
      return Left(ServerFailure('Không tìm thấy playback cho camera $id'));
    }
  }

  @override
  FutureEither<SnapshotReply> snapshot(
    String endpoint, {
    String? etag,
    CancelToken? cancelToken,
  }) async {
    try {
      // In fixture mode, endpoint is an asset path (e.g. assets/fixtures/snapshots/sample1.jpg)
      final ByteData data = await bundle.load(endpoint);
      final bytes = data.buffer.asUint8List();
      return Right(SnapshotReceived(SnapshotFrame(
        bytes: bytes,
        etag: 'fixture-etag-${endpoint.hashCode}',
        fetchedAt: DateTime.now(),
        dataMode: _dataMode,
      )));
    } catch (e) {
      return Left(UnknownFailure('Lỗi tải ảnh snapshot: $e'));
    }
  }
}
