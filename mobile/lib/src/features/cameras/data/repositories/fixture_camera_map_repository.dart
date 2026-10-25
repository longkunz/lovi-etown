import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../utils/failure.dart';
import '../../../../utils/typedefs.dart';
import '../models/camera_dto.dart';
import '../../domain/camera_map_models.dart';
import '../../domain/camera_map_repository.dart';

class FixtureCameraMapRepository implements CameraMapRepository {
  final AssetBundle bundle;
  final String fixturePath;
  FixtureCameraMapRepository(
      {AssetBundle? bundle, this.fixturePath = 'assets/fixtures/cameras.json'})
      : bundle = bundle ?? rootBundle;
  @override
  FutureEither<CameraMapResult> search(CameraMapQuery query,
      {CancelToken? cancelToken}) async {
    if (!query.isValid) {
      return const Left(
          ApiFailure('Vùng tìm kiếm không hợp lệ', statusCode: 400));
    }
    try {
      final json = jsonDecode(await bundle.loadString(fixturePath))
          as Map<String, dynamic>;
      if (cancelToken?.isCancelled ?? false) {
        return const Left(ApiFailure('Yêu cầu đã bị hủy', statusCode: 499));
      }
      final items = <CameraMapItem>[];
      for (final raw in json['items'] as List) {
        final camera =
            CameraDto.fromJson(raw as Map<String, dynamic>).toDomain();
        final lat = camera.latitude, lng = camera.longitude;
        if (lat == null ||
            lng == null ||
            !lat.isFinite ||
            !lng.isFinite ||
            lat.abs() > 90 ||
            lng.abs() > 180) {
          continue;
        }
        if (query.district != null &&
            query.district!.trim().isNotEmpty &&
            camera.district != query.district!.trim()) {
          continue;
        }
        double? distance;
        if (query.isNearby) {
          double rad(double x) => x * math.pi / 180;
          final a = math.pow(math.sin(rad(lat - query.lat!) / 2), 2) +
              math.cos(rad(lat)) *
                  math.cos(rad(query.lat!)) *
                  math.pow(math.sin(rad(lng - query.lng!) / 2), 2);
          distance = 6371008.8 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
          if (distance > query.radiusMeters) {
            continue;
          }
        } else {
          final b = query.bounds!;
          if (lng < b.west || lng > b.east || lat < b.south || lat > b.north) {
            continue;
          }
        }
        items.add(CameraMapItem(camera: camera, distanceMeters: distance));
      }
      items.sort((a, b) {
        final distance =
            query.isNearby ? a.distanceMeters!.compareTo(b.distanceMeters!) : 0;
        return distance != 0 ? distance : a.camera.id.compareTo(b.camera.id);
      });
      return Right(CameraMapResult(
          items: items.take(query.limit).toList(),
          hasMore: items.length > query.limit,
          catalogVersion: json['catalogVersion'] as String? ?? 'fixture-v1',
          dataMode: 'fixture',
          fetchedAt: DateTime.now()));
    } catch (_) {
      return const Left(
          ApiFailure('Không tải được camera bản đồ', statusCode: 500));
    }
  }
}
