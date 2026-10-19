import 'package:dio/dio.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

class ThumbnailScheduler {
  ThumbnailScheduler({
    required CameraRepository repository,
    required SnapshotMemoryCache cache,
  })  : _repository = repository,
        _cache = cache;

  final CameraRepository _repository;
  final SnapshotMemoryCache _cache;

  static const int _maxConcurrent = CameraUiTokens.thumbnailMaxConcurrent; // 4

  final Map<String, CancelToken> _inFlightRequests = {};
  final List<String> _pendingQueue = [];
  final Map<String, String> _endpoints = {};

  String? _activePreviewCameraId;
  String? get activePreviewCameraId => _activePreviewCameraId;

  bool _isForeground = true;
  bool get isForeground => _isForeground;

  void setPreviewCamera(String? cameraId) {
    _activePreviewCameraId = cameraId;
    if (cameraId != null) {
      _pendingQueue.remove(cameraId);
    }
  }

  void setForeground(bool foreground) {
    _isForeground = foreground;
    if (!foreground) {
      _cancelAll();
    } else {
      _pumpQueue();
    }
  }

  void updateWindow({
    required Set<String> visible,
    required Set<String> prefetch,
    Map<String, String>? endpoints,
  }) {
    if (endpoints != null) {
      _endpoints.addAll(endpoints);
    }

    final activeWindow = <String>{...visible, ...prefetch};

    // Cancel requests for items that fell outside the window
    final toCancel = <String>[];
    for (final id in _inFlightRequests.keys) {
      if (!activeWindow.contains(id)) {
        toCancel.add(id);
      }
    }
    for (final id in toCancel) {
      _inFlightRequests.remove(id)?.cancel('Scrolled out of window');
    }

    // Rebuild queue: visible prioritized over prefetch
    _pendingQueue.clear();

    for (final id in visible) {
      if (id == _activePreviewCameraId) continue;
      if (_cache.get(id) != null) continue;
      if (_inFlightRequests.containsKey(id)) continue;
      _pendingQueue.add(id);
    }

    for (final id in prefetch) {
      if (id == _activePreviewCameraId) continue;
      if (_cache.get(id) != null) continue;
      if (_inFlightRequests.containsKey(id)) continue;
      if (!_pendingQueue.contains(id)) {
        _pendingQueue.add(id);
      }
    }

    _pumpQueue();
  }

  void _pumpQueue() {
    if (!_isForeground) return;

    while (
        _inFlightRequests.length < _maxConcurrent && _pendingQueue.isNotEmpty) {
      final nextId = _pendingQueue.removeAt(0);
      final endpoint = _endpoints[nextId];
      if (endpoint == null || endpoint.isEmpty) continue;

      final token = CancelToken();
      _inFlightRequests[nextId] = token;

      _repository.snapshot(endpoint, cancelToken: token).then((result) {
        _inFlightRequests.remove(nextId);

        result.fold(
          (failure) {},
          (reply) {
            if (reply is SnapshotReceived) {
              _cache.put(nextId, reply.frame);
            }
          },
        );

        _pumpQueue();
      }).catchError((_) {
        _inFlightRequests.remove(nextId);
        _pumpQueue();
      });
    }
  }

  void _cancelAll() {
    for (final token in _inFlightRequests.values) {
      token.cancel('Scheduler paused or cancelled');
    }
    _inFlightRequests.clear();
    _pendingQueue.clear();
  }

  void dispose() {
    _cancelAll();
  }
}
