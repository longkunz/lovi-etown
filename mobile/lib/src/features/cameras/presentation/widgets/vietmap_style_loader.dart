import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';

enum VietmapStyleFailureKind {
  missingKey,
  unauthorized,
  timeout,
  network,
  malformed,
  forbiddenHost,
  cancelled
}

class VietmapStyleFailure implements Exception {
  const VietmapStyleFailure(this.kind);
  final VietmapStyleFailureKind kind;
  @override
  String toString() => 'VietmapStyleFailure(${kind.name})';
}

/// This dedicated client never receives the camera backend reader key.
class VietmapStyleLoader {
  VietmapStyleLoader({Dio? client})
      : _client = client ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                followRedirects: false));
  final Dio _client;
  CancelToken _cancel = CancelToken();
  void cancel() {
    _cancel.cancel();
    _cancel = CancelToken();
  }

  void dispose() {
    cancel();
    _client.close(force: true);
  }

  Future<Map<String, dynamic>> load(String style, String apiKey) async {
    if (apiKey.trim().isEmpty || apiKey.startsWith('your_')) {
      throw const VietmapStyleFailure(VietmapStyleFailureKind.missingKey);
    }
    if (!{'tm', 'hm', 'tf'}.contains(style)) {
      throw const VietmapStyleFailure(VietmapStyleFailureKind.malformed);
    }
    final uri = Uri.https('maps.vietmap.vn', '/maps/styles/$style/style.json',
        {'apikey': apiKey});
    final token = _cancel;
    try {
      final response = await _client
          .getUri<Object?>(uri,
              cancelToken: token,
              options: Options(headers: {}, responseType: ResponseType.json))
          .timeout(const Duration(seconds: 10), onTimeout: () {
        token.cancel();
        throw const VietmapStyleFailure(VietmapStyleFailureKind.timeout);
      });
      final raw = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (raw is! Map || raw['sources'] is! Map || raw['layers'] is! List) {
        throw const VietmapStyleFailure(VietmapStyleFailureKind.malformed);
      }
      final result = Map<String, dynamic>.from(raw);
      validateStyle(result);
      validateResources(result);
      return result;
    } on VietmapStyleFailure {
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw const VietmapStyleFailure(VietmapStyleFailureKind.unauthorized);
      }
      if (e.type == DioExceptionType.cancel) {
        throw const VietmapStyleFailure(VietmapStyleFailureKind.cancelled);
      }
      if ({
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout
      }.contains(e.type)) {
        throw const VietmapStyleFailure(VietmapStyleFailureKind.timeout);
      }
      throw const VietmapStyleFailure(VietmapStyleFailureKind.network);
    } catch (_) {
      throw const VietmapStyleFailure(VietmapStyleFailureKind.malformed);
    }
  }

  /// Validate the fields consumed by the merger before crossing the native boundary.
  static void validateStyle(Map<String, dynamic> style) {
    final sources = style['sources'];
    final layers = style['layers'];
    if (sources is! Map ||
        layers is! List ||
        sources.entries
            .any((entry) => entry.key is! String || entry.value is! Map) ||
        layers.any((layer) =>
            layer is! Map ||
            layer['id'] is! String ||
            (layer['id'] as String).trim().isEmpty)) {
      throw const VietmapStyleFailure(VietmapStyleFailureKind.malformed);
    }
  }

  static void validateResources(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if ({'url', 'tiles', 'sprite', 'glyphs'}.contains(entry.key)) {
          _validateUrl(entry.value);
        }
        validateResources(entry.value);
      }
    } else if (value is List) {
      for (final item in value) {
        validateResources(item);
      }
    }
  }

  static void _validateUrl(Object? value) {
    if (value is List) {
      for (final item in value) {
        _validateUrl(item);
      }
      return;
    }
    if (value is! String) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'vietmap.vn' || uri.host.endsWith('.vietmap.vn'))) {
      throw const VietmapStyleFailure(VietmapStyleFailureKind.forbiddenHost);
    }
  }

  static Map<String, dynamic> mergeTraffic(
      Map<String, dynamic> base, Map<String, dynamic> traffic) {
    validateStyle(base);
    validateStyle(traffic);
    final layers = <String, Map<String, dynamic>>{};
    for (final layer in [
      ...base['layers'] as List,
      ...traffic['layers'] as List
    ]) {
      final map = Map<String, dynamic>.from(layer as Map);
      layers[map['id'] as String] = map;
    }
    return {
      ...base,
      'sources': {...base['sources'] as Map, ...traffic['sources'] as Map},
      'layers': layers.values.toList()
    };
  }
}
