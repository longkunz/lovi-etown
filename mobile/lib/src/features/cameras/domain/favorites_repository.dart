import '../../../utils/typedefs.dart';
import 'camera_models.dart';

abstract interface class FavoritesRepository {
  Stream<List<FavoriteCamera>> watch();
  FutureEither<void> load();
  FutureEither<void> setSaved(Camera camera, bool saved);
  FutureEither<void> resetCorruptData();
}
