import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/data/datasources/favorites_local_store.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/local_favorites_repository.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class FakeFavoritesLocalStore implements FavoritesLocalStore {
  String? storedJson;
  bool shouldFailWrite = false;

  @override
  FutureEither<String?> read() async {
    return Right(storedJson);
  }

  @override
  FutureEither<void> write(String json) async {
    if (shouldFailWrite) {
      return const Left(DatabaseFailure('Disk write failed'));
    }
    storedJson = json;
    return const Right(null);
  }

  @override
  FutureEither<void> remove() async {
    storedJson = null;
    return const Right(null);
  }
}

void main() {
  group('LocalFavoritesRepository', () {
    late FakeFavoritesLocalStore store;
    late LocalFavoritesRepository repo;

    const sampleCam1 = Camera(
      id: 'cam-01',
      name: 'Nguyen Hue - Le Loi',
      provinceId: 'tp_hcm',
      district: 'Quan 1',
      address: 'Quan 1',
      playbackEndpoint: '/playback/1',
    );

    const sampleCam2 = Camera(
      id: 'cam-02',
      name: 'Vo Thi Sau - Tran Quoc Thao',
      provinceId: 'tp_hcm',
      district: 'Quan 3',
      playbackEndpoint: '/playback/2',
    );

    setUp(() {
      store = FakeFavoritesLocalStore();
      repo = LocalFavoritesRepository(store: store);
    });

    tearDown(() {
      repo.dispose();
    });

    test('serialized_toggles_survive_restart', () async {
      await repo.load();
      await repo.setSaved(sampleCam1, true);
      await repo.setSaved(sampleCam2, true);

      // Verify store has valid serialized JSON
      expect(store.storedJson, isNotNull);
      expect(store.storedJson, contains('cam-01'));
      expect(store.storedJson, contains('cam-02'));

      // New repository instance simulating app restart
      final newRepo = LocalFavoritesRepository(store: store);
      await newRepo.load();
      final items = await newRepo.watch().first;

      expect(items.length, equals(2));
      expect(items.any((c) => c.id == 'cam-01'), isTrue);
      expect(items.any((c) => c.id == 'cam-02'), isTrue);
      newRepo.dispose();
    });

    test('watch_does_not_miss_a_concurrent_load_emission', () async {
      await repo.load();
      await repo.setSaved(sampleCam1, true);

      final restartedRepo = LocalFavoritesRepository(store: store);
      final firstEmission = Completer<void>();
      final loadedEmission = Completer<List<FavoriteCamera>>();
      late final StreamSubscription<List<FavoriteCamera>> subscription;

      subscription = restartedRepo.watch().listen((items) {
        if (!firstEmission.isCompleted) {
          firstEmission.complete();
          subscription.pause();
          return;
        }
        if (items.any((camera) => camera.id == sampleCam1.id) &&
            !loadedEmission.isCompleted) {
          loadedEmission.complete(items);
        }
      });

      await firstEmission.future;
      await restartedRepo.load();
      subscription.resume();

      final items = await loadedEmission.future.timeout(
        const Duration(seconds: 1),
      );
      expect(items.map((camera) => camera.id), contains(sampleCam1.id));

      await subscription.cancel();
      restartedRepo.dispose();
    });

    test('failed_write_rolls_back_all_surfaces', () async {
      await repo.load();
      store.shouldFailWrite = true;

      final result = await repo.setSaved(sampleCam1, true);
      expect(result.isLeft(), isTrue);

      final items = await repo.watch().first;
      expect(items.isEmpty, isTrue);
    });

    test('corrupt_storage_requires_explicit_reset', () async {
      // Inject corrupt JSON with unknown version
      store.storedJson = '{"version": 999, "items": [{"id": "bad"}]}';

      final loadResult = await repo.load();
      expect(loadResult.isLeft(), isTrue);

      // Store is NOT automatically overwritten on corrupt read
      expect(store.storedJson, isNotNull);

      // Explicit reset
      final resetResult = await repo.resetCorruptData();
      expect(resetResult.isRight(), isTrue);
      expect(store.storedJson, isNull);

      final items = await repo.watch().first;
      expect(items.isEmpty, isTrue);
    });
  });
}
