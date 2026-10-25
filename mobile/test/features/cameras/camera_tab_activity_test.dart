import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/thumbnail_scheduler.dart';
import 'package:flutter_starter/src/features/cameras/data/snapshot/snapshot_memory_cache.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_screen.dart';
import 'camera_screen_test.dart'
    show FakeScreenCameraRepository, FakeFavoritesRepository, FakeAssetLoader;

void main() {
  testWidgets('hidden camera tab pauses thumbnails even when app resumes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final repo = FakeScreenCameraRepository();
    final scheduler =
        ThumbnailScheduler(repository: repo, cache: SnapshotMemoryCache());
    bool active = true;
    late StateSetter rebuild;
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('vi')],
        path: 'assets/translations',
        assetLoader: const FakeAssetLoader(),
        startLocale: const Locale('vi'),
        saveLocale: false,
        child: MaterialApp(home: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return CameraScreen(
              active: active,
              cameraRepository: repo,
              favoritesRepository: FakeFavoritesRepository(),
              thumbnailScheduler: scheduler);
        }))));
    await tester.pumpAndSettle();
    expect(scheduler.isForeground, true);
    rebuild(() => active = false);
    await tester.pumpAndSettle();
    expect(scheduler.isForeground, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(scheduler.isForeground, false);
    rebuild(() => active = true);
    await tester.pumpAndSettle();
    expect(scheduler.isForeground, true);
    await tester.pumpWidget(const SizedBox());
  });
}
