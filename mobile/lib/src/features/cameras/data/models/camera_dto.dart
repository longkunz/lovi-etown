import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';

class CameraDto {
  const CameraDto({
    required this.id,
    required this.name,
    required this.provinceId,
    this.district,
    this.address,
    this.snapshotCapable = true,
    this.thumbnailEndpoint,
    this.snapshotEndpoint,
    required this.playbackEndpoint,
  });

  final String id;
  final String name;
  final String provinceId;
  final String? district;
  final String? address;
  final bool snapshotCapable;
  final String? thumbnailEndpoint;
  final String? snapshotEndpoint;
  final String playbackEndpoint;

  factory CameraDto.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'] as Map<String, dynamic>?;
    final isSnapshotCapable = capabilities != null
        ? (capabilities['snapshot'] as bool? ?? false)
        : (json['snapshotCapable'] as bool? ?? true);

    final id = json['id'] as String;
    final playback = json['playbackEndpoint'] as String? ?? '/v1/cameras/$id/playback';
    final snapshot = json['snapshotEndpoint'] as String? ??
        (isSnapshotCapable ? '/v1/cameras/$id/snapshot' : null);

    return CameraDto(
      id: id,
      name: json['name'] as String,
      provinceId: json['provinceId'] as String? ?? 'tp_hcm',
      district: json['district'] as String?,
      address: json['address'] as String?,
      snapshotCapable: isSnapshotCapable,
      thumbnailEndpoint: json['thumbnailEndpoint'] as String?,
      snapshotEndpoint: snapshot,
      playbackEndpoint: playback,
    );
  }

  Camera toDomain() {
    return Camera(
      id: id,
      name: name,
      provinceId: provinceId,
      district: district,
      address: address,
      snapshotCapable: snapshotCapable,
      thumbnailEndpoint: thumbnailEndpoint,
      snapshotEndpoint: snapshotEndpoint,
      playbackEndpoint: playbackEndpoint,
    );
  }
}

class CatalogPageDto {
  const CatalogPageDto({
    required this.items,
    required this.limit,
    required this.offset,
    required this.total,
    this.catalogVersion = 'v1',
    this.dataMode = 'real',
    this.isStale = false,
  });

  final List<CameraDto> items;
  final int limit;
  final int offset;
  final int total;
  final String catalogVersion;
  final String dataMode;
  final bool isStale;

  factory CatalogPageDto.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['data'] ?? json['items']) as List<dynamic>? ?? [];
    final meta = json['meta'] as Map<String, dynamic>?;
    final pageMeta = meta?['page'] as Map<String, dynamic>?;
    final catalogMeta = meta?['catalog'] as Map<String, dynamic>?;

    final limit = pageMeta?['limit'] as int? ?? json['limit'] as int? ?? 50;
    final offset = pageMeta?['offset'] as int? ?? json['offset'] as int? ?? 0;
    final total =
        pageMeta?['total'] as int? ?? json['total'] as int? ?? rawItems.length;
    final catalogVersion =
        catalogMeta?['version'] as String? ?? json['catalogVersion'] as String? ?? 'v1';
    final dataMode = meta?['dataMode'] as String? ?? 'real';

    return CatalogPageDto(
      items: rawItems
          .map((item) => CameraDto.fromJson(item as Map<String, dynamic>))
          .toList(),
      limit: limit,
      offset: offset,
      total: total,
      catalogVersion: catalogVersion,
      dataMode: dataMode,
      isStale: json['isStale'] as bool? ?? false,
    );
  }

  CatalogPage toDomain({String? overrideDataMode}) {
    return CatalogPage(
      items: items.map((dto) => dto.toDomain()).toList(),
      limit: limit,
      offset: offset,
      total: total,
      catalogVersion: catalogVersion,
      isStale: isStale,
      dataMode: overrideDataMode ?? dataMode,
    );
  }
}
