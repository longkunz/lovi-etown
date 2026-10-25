import 'package:dio/dio.dart';
import '../../../../services/camera_api_client.dart';
import '../../../../utils/typedefs.dart';
import '../../domain/camera_map_models.dart';
import '../../domain/camera_map_repository.dart';

class ApiCameraMapRepository implements CameraMapRepository {
  final CameraApiClient client;
  ApiCameraMapRepository(this.client);
  @override
  FutureEither<CameraMapResult> search(CameraMapQuery query,
          {CancelToken? cancelToken}) =>
      client.getMapCameras(query, cancelToken: cancelToken);
}
