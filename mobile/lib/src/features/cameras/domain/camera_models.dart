import 'dart:typed_data';
import 'package:equatable/equatable.dart';

enum CameraViewMode { card, grid, list }
enum GridDensity { comfortable, compact }

class Camera extends Equatable {
  final String id;
  final String name;
  final String provinceId;
  final String? address;
  final String? district;
  final bool snapshotCapable;
  final String? thumbnailEndpoint;
  final String? snapshotEndpoint;
  final String playbackEndpoint;

  /// Geographic coordinates from the catalog API (`location`), when known.
  /// Used by the "Chỉ đường" (directions) action — see T10.
  final double? latitude;
  final double? longitude;

  /// Live HLS support from the catalog API (T14): [liveCapable] mirrors
  /// `capabilities.live`; [streamUrl] is the public playlist URL.
  final bool liveCapable;
  final String? streamUrl;

  /// Availability status from catalog ('online', 'offline', 'degraded', 'unknown').
  final String availability;

  const Camera({
    required this.id,
    required this.name,
    required this.provinceId,
    this.address,
    this.district,
    this.snapshotCapable = true,
    this.thumbnailEndpoint,
    this.snapshotEndpoint,
    required this.playbackEndpoint,
    this.latitude,
    this.longitude,
    this.liveCapable = false,
    this.streamUrl,
    this.availability = 'unknown',
  });

  bool get hasLocation => latitude != null && longitude != null;

  bool get canLive =>
      liveCapable && streamUrl != null && streamUrl!.isNotEmpty;

  bool get isOnline => availability == 'online';
  bool get isOffline => availability == 'offline';
  bool get isDegraded => availability == 'degraded';

  Camera copyWith({
    String? id,
    String? name,
    String? provinceId,
    String? address,
    String? district,
    bool? snapshotCapable,
    String? thumbnailEndpoint,
    String? snapshotEndpoint,
    String? playbackEndpoint,
    double? latitude,
    double? longitude,
    bool? liveCapable,
    String? streamUrl,
    String? availability,
  }) {
    return Camera(
      id: id ?? this.id,
      name: name ?? this.name,
      provinceId: provinceId ?? this.provinceId,
      address: address ?? this.address,
      district: district ?? this.district,
      snapshotCapable: snapshotCapable ?? this.snapshotCapable,
      thumbnailEndpoint: thumbnailEndpoint ?? this.thumbnailEndpoint,
      snapshotEndpoint: snapshotEndpoint ?? this.snapshotEndpoint,
      playbackEndpoint: playbackEndpoint ?? this.playbackEndpoint,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      liveCapable: liveCapable ?? this.liveCapable,
      streamUrl: streamUrl ?? this.streamUrl,
      availability: availability ?? this.availability,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        provinceId,
        address,
        district,
        snapshotCapable,
        thumbnailEndpoint,
        snapshotEndpoint,
        playbackEndpoint,
        latitude,
        longitude,
        liveCapable,
        streamUrl,
        availability,
      ];
}

class CatalogPage extends Equatable {
  final List<Camera> items;
  final int limit;
  final int offset;
  final int total;
  final String catalogVersion;
  final DateTime? fetchedAt;
  final bool isStale;
  final String? coverage;
  final String? syncState;
  final String dataMode;

  const CatalogPage({
    required this.items,
    required this.limit,
    required this.offset,
    required this.total,
    required this.catalogVersion,
    this.fetchedAt,
    this.isStale = false,
    this.coverage,
    this.syncState,
    this.dataMode = 'real',
  });

  bool get hasMore => offset + items.length < total;

  @override
  List<Object?> get props => [
        items,
        limit,
        offset,
        total,
        catalogVersion,
        fetchedAt,
        isStale,
        coverage,
        syncState,
        dataMode,
      ];
}

class DistrictOption extends Equatable {
  final String name;
  final int count;
  final int? onlineCount;

  const DistrictOption({
    required this.name,
    required this.count,
    this.onlineCount,
  });

  @override
  List<Object?> get props => [name, count, onlineCount];
}

class PlaybackDescriptor extends Equatable {
  final String cameraId;
  final String kind;
  final String snapshotEndpoint;
  final int refreshIntervalMs;
  final DateTime? capturedAt;

  const PlaybackDescriptor({
    required this.cameraId,
    required this.kind,
    required this.snapshotEndpoint,
    required this.refreshIntervalMs,
    this.capturedAt,
  });

  @override
  List<Object?> get props => [
        cameraId,
        kind,
        snapshotEndpoint,
        refreshIntervalMs,
        capturedAt,
      ];
}

class SnapshotFrame extends Equatable {
  final Uint8List bytes;
  final String? etag;
  final DateTime? fetchedAt;
  final String dataMode;

  const SnapshotFrame({
    required this.bytes,
    this.etag,
    this.fetchedAt,
    this.dataMode = 'real',
  });

  @override
  List<Object?> get props => [bytes, etag, fetchedAt, dataMode];
}

sealed class SnapshotReply extends Equatable {
  const SnapshotReply();
}

class SnapshotReceived extends SnapshotReply {
  final SnapshotFrame frame;

  const SnapshotReceived(this.frame);

  @override
  List<Object?> get props => [frame];
}

class SnapshotUnchanged extends SnapshotReply {
  const SnapshotUnchanged();

  @override
  List<Object?> get props => [];
}

class FavoriteCamera extends Equatable {
  final String id;
  final String name;
  final String? district;
  final String? address;
  final DateTime addedAt;
  final bool isMissingFromCatalog;

  const FavoriteCamera({
    required this.id,
    required this.name,
    this.district,
    this.address,
    required this.addedAt,
    this.isMissingFromCatalog = false,
  });

  FavoriteCamera copyWith({
    String? id,
    String? name,
    String? district,
    String? address,
    DateTime? addedAt,
    bool? isMissingFromCatalog,
  }) {
    return FavoriteCamera(
      id: id ?? this.id,
      name: name ?? this.name,
      district: district ?? this.district,
      address: address ?? this.address,
      addedAt: addedAt ?? this.addedAt,
      isMissingFromCatalog: isMissingFromCatalog ?? this.isMissingFromCatalog,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (district != null) 'district': district,
      if (address != null) 'address': address,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory FavoriteCamera.fromJson(Map<String, dynamic> json) {
    return FavoriteCamera(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String?,
      address: json['address'] as String?,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      isMissingFromCatalog: json['isMissingFromCatalog'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        district,
        address,
        addedAt,
        isMissingFromCatalog,
      ];
}
