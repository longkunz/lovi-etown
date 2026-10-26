import 'package:flutter_starter/src/features/cameras/domain/camera_map_models.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/config/app_config.dart';
import 'package:flutter_starter/src/features/cameras/data/models/camera_dto.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/logger.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

extension _UriPortExtension on Uri {
  int get effectivePort => hasPort ? port : (scheme == 'https' ? 443 : 80);
}

class CameraApiClient {
  CameraApiClient({
    required Dio dio,
    required CameraConnectionConfig config,
  })  : _dio = dio,
        _config = config;

  final Dio _dio;
  final CameraConnectionConfig _config;

  bool get _isConfigValid =>
      _config.baseUrl.trim().isNotEmpty && _config.readerKey.trim().isNotEmpty;

  Map<String, String> _buildHeaders() {
    return {
      'x-api-key': _config.readerKey,
    };
  }

  bool _isSafeOrigin(String endpoint) {
    final parsedUri = Uri.tryParse(endpoint);
    if (parsedUri == null) {
      return false;
    }
    if (!parsedUri.hasScheme) {
      // Relative endpoint is safe
      return true;
    }

    final baseUri = Uri.tryParse(_config.baseUrl);
    if (baseUri == null) {
      return false;
    }

    // Strict origin validation: scheme, host, port, no userInfo
    if (parsedUri.scheme != baseUri.scheme) {
      return false;
    }
    if (parsedUri.host != baseUri.host) {
      return false;
    }
    if (parsedUri.effectivePort != baseUri.effectivePort) {
      return false;
    }
    if (parsedUri.userInfo.isNotEmpty) {
      return false;
    }

    return true;
  }

  FutureEither<CameraMapResult> getMapCameras(CameraMapQuery query,
      {CancelToken? cancelToken}) async {
    if (!_isConfigValid) {
      return const Left(ApiFailure('Chưa cấu hình máy chủ', statusCode: 0));
    }
    if (!query.isValid) {
      return const Left(
          ApiFailure('Vùng tìm kiếm không hợp lệ', statusCode: 400));
    }
    try {
      final b = query.bounds;
      final response = await _dio.get<dynamic>(
          '${_config.baseUrl}/v1/map-cameras',
          queryParameters: {
            'provinceId': 'tp_hcm',
            'limit': query.limit,
            if (query.district != null && query.district!.trim().isNotEmpty)
              'district': query.district!.trim(),
            if (b != null) 'bbox': '${b.west},${b.south},${b.east},${b.north}',
            if (query.isNearby) ...{
              'lat': query.lat,
              'lng': query.lng,
              'radiusMeters': query.radiusMeters
            },
          },
          options: Options(
              headers: _buildHeaders(),
              followRedirects: false,
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15)),
          cancelToken: cancelToken);
      final decoded = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      final json = decoded as Map<String, dynamic>;
      final meta = json['meta'] as Map<String, dynamic>;
      final result = meta['result'] as Map<String, dynamic>;
      final catalog = meta['catalog'] as Map<String, dynamic>;
      final items = (json['data'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        final distance = (item['distanceMeters'] as num?)?.toDouble();
        if (distance != null && (!distance.isFinite || distance < 0)) {
          throw const FormatException('Invalid distance');
        }
        return CameraMapItem(
            camera: CameraDto.fromJson(item['camera'] as Map<String, dynamic>)
                .toDomain(),
            distanceMeters: distance);
      }).toList();
      return Right(CameraMapResult(
          items: items,
          hasMore: result['hasMore'] as bool,
          catalogVersion: catalog['version'] as String,
          fetchedAt: catalog['fetchedAt'] == null
              ? null
              : DateTime.parse(catalog['fetchedAt'] as String),
          isStale: catalog['isStale'] as bool? ?? false,
          coverage: catalog['coverage'] as String?,
          syncState: catalog['syncState'] as String?,
          dataMode: meta['dataMode'] as String? ?? 'real'));
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (_) {
      return const Left(
          ApiFailure('Phản hồi bản đồ không hợp lệ', statusCode: 500));
    }
  }

  FutureEither<CatalogPage> getCatalog({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    if (!_isConfigValid) {
      return const Left(ApiFailure(
        'Chưa cấu hình máy chủ hoặc mã truy cập camera',
        statusCode: 0,
      ));
    }

    try {
      final queryParams = <String, dynamic>{
        'provinceId': 'tp_hcm',
        'limit': limit,
        'offset': offset,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (district != null && district.trim().isNotEmpty)
          'district': district.trim(),
      };

      final response = await _dio.get<dynamic>(
        '${_config.baseUrl}/v1/cameras',
        queryParameters: queryParams,
        options: Options(
          headers: _buildHeaders(),
          followRedirects: false,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      final data = response.data;
      final Map<String, dynamic> jsonMap;
      if (data is String) {
        jsonMap = jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        jsonMap = data;
      } else {
        return const Left(
            ApiFailure('Phản hồi máy chủ không hợp lệ', statusCode: 500));
      }

      final dto = CatalogPageDto.fromJson(jsonMap);
      return Right(dto.toDomain());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (e) {
      return Left(ApiFailure('Lỗi không xác định: $e', statusCode: 500));
    }
  }

  FutureEither<List<DistrictOption>> getDistricts(
      {CancelToken? cancelToken}) async {
    if (!_isConfigValid) {
      return const Left(ApiFailure('Chưa cấu hình máy chủ', statusCode: 0));
    }

    try {
      final response = await _dio.get<dynamic>(
        '${_config.baseUrl}/v1/camera-districts',
        queryParameters: const {'provinceId': 'tp_hcm'},
        options: Options(
          headers: _buildHeaders(),
          followRedirects: false,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      final data = response.data;
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List<dynamic>;
      } else {
        return const Right([]);
      }

      final options = list.map((item) {
        if (item is Map<String, dynamic>) {
          return DistrictOption(
            name: item['name'] as String? ?? item['district'] as String? ?? '',
            count: item['count'] as int? ?? item['cameraCount'] as int? ?? 0,
            onlineCount: item['onlineCount'] as int?,
          );
        }
        return DistrictOption(name: item.toString(), count: 0);
      }).toList();

      return Right(options);
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (e) {
      return Left(ApiFailure('Lỗi không xác định: $e', statusCode: 500));
    }
  }

  FutureEither<Camera> getCamera(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (!_isConfigValid) {
      return const Left(ApiFailure('Chưa cấu hình máy chủ', statusCode: 0));
    }

    try {
      final response = await _dio.get<dynamic>(
        '${_config.baseUrl}/v1/cameras/$id',
        options: Options(
          headers: _buildHeaders(),
          followRedirects: false,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      final data = response.data;
      final Map<String, dynamic> jsonMap;
      if (data is String) {
        jsonMap = jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        jsonMap = data.containsKey('data') && data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data;
      } else {
        return const Left(
            ApiFailure('Phản hồi chi tiết không hợp lệ', statusCode: 500));
      }

      final dto = CameraDto.fromJson(jsonMap);
      return Right(dto.toDomain());
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (e) {
      return Left(ApiFailure('Lỗi không xác định: $e', statusCode: 500));
    }
  }

  FutureEither<PlaybackDescriptor> getPlayback(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (!_isConfigValid) {
      return const Left(ApiFailure('Chưa cấu hình máy chủ', statusCode: 0));
    }

    try {
      final response = await _dio.get<dynamic>(
        '${_config.baseUrl}/v1/cameras/$id/playback',
        options: Options(
          headers: _buildHeaders(),
          followRedirects: false,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      final data = response.data;
      final Map<String, dynamic> jsonMap;
      if (data is String) {
        jsonMap = jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        jsonMap = data.containsKey('data') && data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data;
      } else {
        return const Left(
            ApiFailure('Phản hồi luồng phát không hợp lệ', statusCode: 500));
      }

      DateTime? capturedAt;
      if (jsonMap['capturedAt'] != null) {
        capturedAt = DateTime.tryParse(jsonMap['capturedAt'] as String);
      }

      return Right(PlaybackDescriptor(
        cameraId: jsonMap['cameraId'] as String? ?? id,
        kind: jsonMap['kind'] as String? ?? 'snapshot',
        snapshotEndpoint: jsonMap['snapshotEndpoint'] as String? ??
            '/v1/cameras/$id/snapshot',
        refreshIntervalMs: jsonMap['refreshIntervalMs'] as int? ?? 12000,
        capturedAt: capturedAt,
      ));
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (e) {
      return Left(ApiFailure('Lỗi không xác định: $e', statusCode: 500));
    }
  }

  FutureEither<List<Camera>> getRelated(
    String id, {
    int limit = 6,
    CancelToken? cancelToken,
  }) async {
    if (!_isConfigValid) {
      return const Left(ApiFailure('Chưa cấu hình máy chủ', statusCode: 0));
    }

    try {
      final response = await _dio.get<dynamic>(
        '${_config.baseUrl}/v1/cameras/$id/related',
        queryParameters: {'limit': limit},
        options: Options(
          headers: _buildHeaders(),
          followRedirects: false,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      final data = response.data;
      final dynamic decoded = data is String ? jsonDecode(data) : data;
      final List<dynamic> rawItems;
      if (decoded is Map<String, dynamic> && decoded['data'] is List<dynamic>) {
        rawItems = decoded['data'] as List<dynamic>;
      } else if (decoded is List<dynamic>) {
        rawItems = decoded;
      } else {
        return const Left(
            ApiFailure('Phản hồi camera liên quan không hợp lệ', statusCode: 500));
      }

      final cameras = rawItems
          .map((item) =>
              CameraDto.fromJson(item as Map<String, dynamic>).toDomain())
          .toList();
      return Right(cameras);
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (e) {
      return Left(ApiFailure('Lỗi không xác định: $e', statusCode: 500));
    }
  }

  FutureEither<SnapshotReply> getSnapshot(
    String endpoint, {
    String? etag,
    CancelToken? cancelToken,
  }) async {
    // Security check: reject cross-origin or invalid scheme/port attempts
    if (!_isSafeOrigin(endpoint)) {
      return const Left(ApiFailure(
        'Endpoint không hợp lệ hoặc trái origin',
        statusCode: 400,
      ));
    }

    if (!_isConfigValid) {
      return const Left(ApiFailure('Chưa cấu hình máy chủ', statusCode: 0));
    }

    try {
      final url = endpoint.startsWith('http')
          ? endpoint
          : '${_config.baseUrl}${endpoint.startsWith('/') ? '' : '/'}$endpoint';

      final headers = _buildHeaders();
      if (etag != null && etag.trim().isNotEmpty) {
        headers['If-None-Match'] = etag.trim();
      }

      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && (status == 200 || status == 304),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
        cancelToken: cancelToken,
      );

      final statusCode = response.statusCode ?? 200;
      if (statusCode == 304) {
        return const Right(SnapshotUnchanged());
      }

      final responseBody = response.data;
      if (responseBody == null) {
        return const Left(
            ApiFailure('Không nhận được luồng dữ liệu ảnh', statusCode: 500));
      }

      // Stream accumulation bounded to 2 MiB
      final bytesBuilder = BytesBuilder(copy: false);
      var totalBytes = 0;

      await for (final chunk in responseBody.stream) {
        totalBytes += chunk.length;
        if (totalBytes > CameraUiTokens.snapshotMaxSizeBytes) {
          cancelToken?.cancel('Dung lượng hình ảnh vượt quá giới hạn 2 MiB');
          return const Left(ApiFailure(
            'Dung lượng hình ảnh vượt quá giới hạn 2 MiB',
            statusCode: 413,
          ));
        }
        bytesBuilder.add(chunk);
      }

      final bytes = bytesBuilder.takeBytes();
      if (!_isValidImageHeader(bytes) || !await _isDecodableImage(bytes)) {
        return const Left(ApiFailure(
          'Dữ liệu hình ảnh không hợp lệ hoặc bị lỗi',
          statusCode: 422,
        ));
      }

      final responseEtag = response.headers.value('etag');
      final frame = SnapshotFrame(
        bytes: bytes,
        etag: responseEtag,
        fetchedAt: DateTime.now(),
        dataMode: 'real',
      );

      return Right(SnapshotReceived(frame));
    } on DioException catch (e) {
      return Left(_mapDioException(e));
    } catch (e) {
      return Left(ApiFailure('Lỗi không xác định: $e', statusCode: 500));
    }
  }

  /// Full decode check (T01): a valid header / magic bytes alone is not
  /// enough, because a payload can carry a correct header and still be
  /// undecodable. Only bytes that actually decode to a frame may become a
  /// [SnapshotFrame], so a corrupt payload can never replace the last good
  /// frame in the preview, the viewer or the shared snapshot cache.
  Future<bool> _isDecodableImage(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      return true;
    } catch (e, stackTrace) {
      // Any codec error means the payload is not a usable image; the caller
      // maps this to the same 422 failure as an invalid header. Log the
      // error (never the payload or headers) so field failures stay
      // debuggable.
      AppLogger.log(
        'Snapshot payload failed image decode',
        category: LogCategory.network,
        context: {'bytes': bytes.length},
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      codec?.dispose();
    }
  }

  bool _isValidImageHeader(Uint8List bytes) {
    if (bytes.length < 64) return false;

    // JPEG: 0xFF, 0xD8
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      // Must contain valid marker after SOI (0xFF followed by 0xE0..0xFE or SOF 0xC0..0xCF)
      // or end with EOI 0xFF, 0xD9
      if (bytes[2] == 0xFF && bytes[3] >= 0xC0) {
        return true;
      }
      if (bytes[bytes.length - 2] == 0xFF && bytes[bytes.length - 1] == 0xD9) {
        return true;
      }
      return false;
    }

    // PNG: 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    // GIF: GIF87a or GIF89a
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }

    // WebP: RIFF .... WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  ApiFailure _mapDioException(DioException e) {
    final status = e.response?.statusCode ?? 500;
    final message = switch (e.type) {
      DioExceptionType.connectionTimeout => 'Hết thời gian kết nối đến máy chủ',
      DioExceptionType.receiveTimeout => 'Hết thời gian nhận dữ liệu',
      DioExceptionType.cancel => 'Yêu cầu đã bị hủy',
      DioExceptionType.badResponse when status == 401 || status == 403 =>
        'Mã truy cập không hợp lệ',
      DioExceptionType.badResponse when status == 404 =>
        'Không tìm thấy dữ liệu',
      DioExceptionType.badResponse when status == 429 =>
        'Quá nhiều yêu cầu, vui lòng thử lại sau',
      _ => 'Lỗi kết nối máy chủ camera',
    };

    Duration? retryAfter;
    if (status == 429) {
      final header = e.response?.headers.value('retry-after');
      if (header != null) {
        final seconds = int.tryParse(header.trim());
        if (seconds != null) {
          retryAfter = Duration(seconds: seconds);
        }
      }
    }

    final isRetryable = status == 429 ||
        status >= 500 ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout;

    return ApiFailure(
      message,
      statusCode: status,
      retryable: isRetryable,
      retryAfter: retryAfter,
      error: e,
    );
  }
}
