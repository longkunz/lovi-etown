import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';

/// Where widget data goes (T15). The production implementation talks to
/// the home_widget plugin; tests substitute a fake.
abstract class WidgetDataSink {
  Future<void> save(String key, String value);
  Future<void> requestUpdate();
}

class HomeWidgetDataSink implements WidgetDataSink {
  /// Qualified Android provider class registered in the manifest.
  static const qualifiedAndroidName = 'site.capyai.lovi.LoviWidgetProvider';

  @override
  Future<void> save(String key, String value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> requestUpdate() => HomeWidget.updateWidget(
        androidName: 'LoviWidgetProvider',
        qualifiedAndroidName: qualifiedAndroidName,
      );
}

/// Keeps the Android home-screen widget in sync with the user's first
/// favorite camera (T15): resolves the favorite, fetches a fresh snapshot,
/// stores the image file + name + update time for the native provider to
/// render. Best-effort by design — every failure is swallowed so widget
/// sync can never break the app.
class HomeWidgetSyncService {
  HomeWidgetSyncService({
    required CameraRepository repository,
    required WidgetDataSink sink,
    required Future<Directory> Function() filesDir,
    DateTime Function()? now,
  })  : _repository = repository,
        _sink = sink,
        _filesDir = filesDir,
        _now = now ?? DateTime.now;

  factory HomeWidgetSyncService.production(CameraRepository repository) {
    return HomeWidgetSyncService(
      repository: repository,
      sink: HomeWidgetDataSink(),
      filesDir: getApplicationSupportDirectory,
    );
  }

  final CameraRepository _repository;
  final WidgetDataSink _sink;
  final Future<Directory> Function() _filesDir;
  final DateTime Function() _now;

  static const snapshotFileName = 'lovi_widget_snapshot.jpg';

  Future<void> sync(List<FavoriteCamera> favorites) async {
    try {
      if (favorites.isEmpty) {
        await _sink.save('cameraName', '');
        await _sink.save('imagePath', '');
        await _sink.save('updatedAt', '');
        await _sink.requestUpdate();
        return;
      }

      final favorite = favorites.first;
      final detail = await _repository.detail(favorite.id);
      final camera = detail.fold<Camera?>((_) => null, (c) => c);
      if (camera == null) return;
      final endpoint = camera.snapshotEndpoint;
      if (endpoint == null || endpoint.isEmpty) return;

      final reply = await _repository.snapshot(endpoint);
      final frame = reply.fold<SnapshotFrame?>(
        (_) => null,
        (r) => r is SnapshotReceived ? r.frame : null,
      );
      if (frame == null || frame.bytes.isEmpty) return;

      final dir = await _filesDir();
      final file = File('${dir.path}/$snapshotFileName');
      await file.writeAsBytes(frame.bytes, flush: true);

      final t = _now();
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      await _sink.save('cameraName', camera.name);
      await _sink.save('imagePath', file.path);
      await _sink.save('updatedAt', '$hh:$mm');
      await _sink.requestUpdate();
    } catch (_) {
      // Widget sync is decorative; never propagate failures.
    }
  }
}
