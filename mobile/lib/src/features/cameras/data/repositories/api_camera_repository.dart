import 'package:dio/dio.dart';
import '../../../../utils/typedefs.dart';
import 'package:flutter_starter/src/services/camera_api_client.dart';
import '../../domain/camera_models.dart';
import '../../domain/camera_repository.dart';

/// Triển khai CameraRepository sử dụng CameraApiClient kết nối tới backend REST API.
class ApiCameraRepository implements CameraRepository {
  ApiCameraRepository({
    required CameraApiClient apiClient,
  }) : _apiClient = apiClient;

  final CameraApiClient _apiClient;

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) {
    return _apiClient.getCatalog(
      query: query,
      district: district,
      limit: limit,
      offset: offset,
      cancelToken: cancelToken,
    );
  }

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) {
    return _apiClient.getDistricts(cancelToken: cancelToken);
  }

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) {
    return _apiClient.getCamera(id, cancelToken: cancelToken);
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
      {CancelToken? cancelToken}) {
    return _apiClient.getPlayback(id, cancelToken: cancelToken);
  }

  @override
  FutureEither<SnapshotReply> snapshot(
    String endpoint, {
    String? etag,
    CancelToken? cancelToken,
  }) {
    return _apiClient.getSnapshot(
      endpoint,
      etag: etag,
      cancelToken: cancelToken,
    );
  }
}
