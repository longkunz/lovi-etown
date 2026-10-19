import 'dart:async';
import 'dart:convert';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/features/cameras/data/datasources/favorites_local_store.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

class LocalFavoritesRepository implements FavoritesRepository {
  LocalFavoritesRepository({required FavoritesLocalStore store}) : _store = store;

  final FavoritesLocalStore _store;
  final List<FavoriteCamera> _cachedFavorites = [];
  final StreamController<List<FavoriteCamera>> _controller =
      StreamController<List<FavoriteCamera>>.broadcast();

  Future<dynamic> _lock = Future.value();

  static const int currentSchemaVersion = 1;

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final prev = _lock;
    final completer = Completer<T>();
    _lock = prev.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield List.unmodifiable(_cachedFavorites);
    yield* _controller.stream;
  }

  @override
  FutureEither<void> load() => _synchronized(() async {
        final readResult = await _store.read();

        return readResult.fold(
          (failure) => Left(failure),
          (rawJson) {
            if (rawJson == null || rawJson.trim().isEmpty) {
              _cachedFavorites.clear();
              _controller.add(const []);
              return const Right(null);
            }

            try {
              final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
              final version = decoded['version'] as int?;

              if (version != currentSchemaVersion) {
                return Left(DatabaseFailure(
                  'Phiên bản dữ liệu không tương thích ($version != $currentSchemaVersion)',
                ));
              }

              final rawItems = decoded['items'] as List<dynamic>? ?? [];
              final items = rawItems
                  .map((item) => FavoriteCamera.fromJson(item as Map<String, dynamic>))
                  .toList();

              _cachedFavorites
                ..clear()
                ..addAll(items);
              _controller.add(List.unmodifiable(_cachedFavorites));
              return const Right(null);
            } catch (e) {
              return Left(DatabaseFailure('Dữ liệu lưu trữ bị lỗi: $e'));
            }
          },
        );
      });

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) => _synchronized(() async {
        final nextList = List<FavoriteCamera>.from(_cachedFavorites);

        if (saved) {
          final existingIndex = nextList.indexWhere((f) => f.id == camera.id);
          if (existingIndex < 0) {
            nextList.add(FavoriteCamera(
              id: camera.id,
              name: camera.name,
              district: camera.district,
              address: camera.address,
              addedAt: DateTime.now(),
            ));
          }
        } else {
          nextList.removeWhere((f) => f.id == camera.id);
        }

        // Prepare versioned JSON payload
        final payload = {
          'version': currentSchemaVersion,
          'items': nextList.map((f) => f.toJson()).toList(),
        };
        final serialized = jsonEncode(payload);

        // Persist to store
        final writeResult = await _store.write(serialized);

        return writeResult.fold(
          (failure) {
            // Rollback: do not mutate memory cache or emit
            return Left(failure);
          },
          (_) {
            // Success: update cache and emit
            _cachedFavorites
              ..clear()
              ..addAll(nextList);
            _controller.add(List.unmodifiable(_cachedFavorites));
            return const Right(null);
          },
        );
      });

  @override
  FutureEither<void> resetCorruptData() => _synchronized(() async {
        final removeResult = await _store.remove();
        return removeResult.fold(
          (failure) => Left(failure),
          (_) {
            _cachedFavorites.clear();
            _controller.add(const []);
            return const Right(null);
          },
        );
      });

  void dispose() {
    _controller.close();
  }
}
