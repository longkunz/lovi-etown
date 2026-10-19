import 'package:flutter_starter/src/utils/utils.dart';
import 'package:flutter_starter/src/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/src/features/auth/domain/repositories/auth_repository.dart';

/// Record-shaped login credentials.
typedef LoginParams = ({String email, String password});

class LoginUseCase implements UseCase<LoginParams, AppUser> {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  @override
  FutureEither<AppUser> call(LoginParams params) {
    final (:email, :password) = params;
    return _repository.login(email: email, password: password);
  }
}
