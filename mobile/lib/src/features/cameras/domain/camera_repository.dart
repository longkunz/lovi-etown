import 'package:dio/dio.dart';
import '../../../utils/typedefs.dart';
import 'camera_models.dart';

abstract interface class CameraRepository {
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  });

  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken});

  FutureEither<Camera> detail(String id, {CancelToken? cancelToken});

  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken});

  FutureEither<SnapshotReply> snapshot(
    String endpoint, {
    String? etag,
    CancelToken? cancelToken,
  });
}
