import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:dio/dio.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_favorites_cubit.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class FakeRevalidationCameraRepository implements CameraRepository {
  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      const Right([]);

  int activeConcurrentCalls = 0;
  int maxConcurrentCallsObserved = 0;
  final Map<String, Camera> knownCameras = {};
  final Set<String> networkErrorIds = {};

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async {
    activeConcurrentCalls++;
    if (activeConcurrentCalls > maxConcurrentCallsObserved) {
      maxConcurrentCallsObserved = activeConcurrentCalls;
    }

    // Small delay to test concurrency
    await Future<void>.delayed(const Duration(milliseconds: 30));
    activeConcurrentCalls--;

    if (networkErrorIds.contains(id)) {
      return const Left(NetworkFailure('Connection error'));
    }

    final found = knownCameras[id];
    if (found != null) {
      return Right(found);
    }
    return const Left(ServerFailure('404 Not Found'));
  }

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint, {String? etag, CancelToken? cancelToken}) async {
    throw UnimplementedError();
  }
}

class FakeInMemoryFavoritesRepository implements FavoritesRepository {
  final List<FavoriteCamera> _favorites = [];
  final StreamController<List<FavoriteCamera>> _controller =
      StreamController<List<FavoriteCamera>>.broadcast();

  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield List.unmodifiable(_favorites);
    yield* _controller.stream;
  }

  @override
  FutureEither<void> load() async {
    _controller.add(List.unmodifiable(_favorites));
    return const Right(null);
  }

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async {
    if (saved) {
      final existingIndex = _favorites.indexWhere((f) => f.id == camera.id);
      if (existingIndex < 0) {
        _favorites.add(FavoriteCamera(
          id: camera.id,
          name: camera.name,
          district: camera.district,
          address: camera.address,
          addedAt: DateTime.now(),
        ));
      }
    } else {
      _favorites.removeWhere((f) => f.id == camera.id);
    }
    _controller.add(List.unmodifiable(_favorites));
    return const Right(null);
  }

  @override
  FutureEither<void> resetCorruptData() async {
    _favorites.clear();
    _controller.add(const []);
    return const Right(null);
  }

  void addDirect(FavoriteCamera fav) {
    _favorites.add(fav);
    _controller.add(List.unmodifiable(_favorites));
  }

  void updateDirect(FavoriteCamera fav) {
    final idx = _favorites.indexWhere((f) => f.id == fav.id);
    if (idx >= 0) {
      _favorites[idx] = fav;
      _controller.add(List.unmodifiable(_favorites));
    }
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('CameraFavoritesCubit', () {
    late FakeInMemoryFavoritesRepository favRepo;
    late FakeRevalidationCameraRepository camRepo;
    late CameraFavoritesCubit cubit;

    setUp(() {
      favRepo = FakeInMemoryFavoritesRepository();
      camRepo = FakeRevalidationCameraRepository();
      cubit = CameraFavoritesCubit(favoritesRepository: favRepo);
    });

    tearDown(() {
      cubit.close();
      favRepo.dispose();
    });

    test('metadata_404_retains_removable_favorite', () async {
      final fav = FavoriteCamera(
        id: 'cam-deleted',
        name: 'Deleted Camera',
        district: 'Quan 1',
        addedAt: DateTime.now(),
      );
      favRepo.addDirect(fav);
      await cubit.init();

      // Revalidate against repo where cam-deleted is not found (404)
      await cubit.revalidate(camRepo);

      final current = cubit.state.favorites.firstWhere((f) => f.id == 'cam-deleted');
      expect(current.isMissingFromCatalog, isTrue);

      // User can still toggle/remove it!
      await cubit.toggle(const Camera(
        id: 'cam-deleted',
        name: 'Deleted Camera',
        provinceId: 'tp_hcm',
        playbackEndpoint: '',
      ));

      expect(cubit.state.favorites.any((f) => f.id == 'cam-deleted'), isFalse);
    });

    test('metadata_network_error_keeps_last_known_name', () async {
      final fav = FavoriteCamera(
        id: 'cam-net-err',
        name: 'Nguyen Hue Last Known',
        district: 'Quan 1',
        addedAt: DateTime.now(),
      );
      favRepo.addDirect(fav);
      camRepo.networkErrorIds.add('cam-net-err');

      await cubit.init();
      await cubit.revalidate(camRepo);

      final current = cubit.state.favorites.firstWhere((f) => f.id == 'cam-net-err');
      expect(current.name, equals('Nguyen Hue Last Known'));
      expect(current.isMissingFromCatalog, isFalse);
    });

    test('revalidation_max_four', () async {
      // Add 10 favorites
      for (int i = 1; i <= 10; i++) {
        final id = 'cam-$i';
        favRepo.addDirect(FavoriteCamera(
          id: id,
          name: 'Camera $i',
          addedAt: DateTime.now(),
        ));
        camRepo.knownCameras[id] = Camera(
          id: id,
          name: 'Updated Camera $i',
          provinceId: 'tp_hcm',
          playbackEndpoint: '',
        );
      }

      await cubit.init();
      await cubit.revalidate(camRepo);

      // Verify that concurrent requests never exceeded 4!
      expect(camRepo.maxConcurrentCallsObserved, lessThanOrEqualTo(4));
      expect(cubit.state.favorites.length, equals(10));
      expect(cubit.state.favorites.first.name, equals('Updated Camera 1'));
    });
  });
}
