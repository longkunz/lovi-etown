import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/services/storage_service.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

abstract interface class FavoritesLocalStore {
  FutureEither<String?> read();
  FutureEither<void> write(String json);
  FutureEither<void> remove();
}

class SharedPreferencesFavoritesLocalStore implements FavoritesLocalStore {
  SharedPreferencesFavoritesLocalStore({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;
  static const String key = 'camera_favorites_v1';

  @override
  FutureEither<String?> read() async {
    try {
      final value = _storage.getString(key);
      return Right(value);
    } catch (e) {
      return Left(DatabaseFailure('Không thể đọc dữ liệu lưu trữ: $e'));
    }
  }

  @override
  FutureEither<void> write(String json) async {
    final result = await _storage.setString(key, json);
    return result.fold(
      (failure) => Left(failure),
      (success) => success
          ? const Right(null)
          : const Left(DatabaseFailure('Không thể ghi dữ liệu cục bộ')),
    );
  }

  @override
  FutureEither<void> remove() async {
    final result = await _storage.remove(key);
    return result.fold(
      (failure) => Left(failure),
      (success) => success
          ? const Right(null)
          : const Left(DatabaseFailure('Không thể xóa dữ liệu cục bộ')),
    );
  }
}
