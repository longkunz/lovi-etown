import 'package:dio/dio.dart';
import '../../../utils/typedefs.dart';
import 'camera_map_models.dart';

abstract interface class CameraMapRepository {
  FutureEither<CameraMapResult> search(CameraMapQuery query,
      {CancelToken? cancelToken});
}
