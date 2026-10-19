import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

class SnapshotMemoryCache extends ChangeNotifier {
  SnapshotMemoryCache({
    this.maxBytes = CameraUiTokens.snapshotCacheMaxBytes,
    this.maxEntries = CameraUiTokens.snapshotCacheMaxEntries,
  });

  final int maxBytes;
  final int maxEntries;

  final LinkedHashMap<String, SnapshotFrame> _entries = LinkedHashMap();
  int _currentByteSize = 0;

  int get currentByteSize => _currentByteSize;
  int get entryCount => _entries.length;

  SnapshotFrame? get(String key) {
    final frame = _entries.remove(key);
    if (frame != null) {
      _entries[key] = frame; // re-insert at end (most recently used)
    }
    return frame;
  }

  void put(String key, SnapshotFrame frame) {
    if (_entries.containsKey(key)) {
      final oldFrame = _entries.remove(key)!;
      _currentByteSize -= oldFrame.bytes.length;
    }

    _entries[key] = frame;
    _currentByteSize += frame.bytes.length;

    _evictIfNeeded();
    notifyListeners();
  }

  void remove(String key) {
    final frame = _entries.remove(key);
    if (frame != null) {
      _currentByteSize -= frame.bytes.length;
      notifyListeners();
    }
  }

  void clear() {
    _entries.clear();
    _currentByteSize = 0;
    notifyListeners();
  }

  void _evictIfNeeded() {
    while (_entries.isNotEmpty &&
        (_entries.length > maxEntries || _currentByteSize > maxBytes)) {
      final oldestKey = _entries.keys.first;
      final evicted = _entries.remove(oldestKey);
      if (evicted != null) {
        _currentByteSize -= evicted.bytes.length;
      }
    }
  }
}
