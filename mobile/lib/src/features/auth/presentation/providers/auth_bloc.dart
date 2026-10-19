import 'package:flutter_starter/src/imports/core_imports.dart';
import 'package:flutter_starter/src/imports/packages_imports.dart';
import 'package:flutter_starter/src/features/auth/domain/repositories/auth_repository.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class LoginRequested extends AuthEvent {
  const LoginRequested({
    required this.context,
    required this.email,
    required this.password,
  });

  final BuildContext context;
  final String email;
  final String password;
}

final class SignUpRequested extends AuthEvent {
  const SignUpRequested({
    required this.context,
    required this.name,
    required this.email,
    required this.password,
  });

  final BuildContext context;
  final String name;
  final String email;
  final String password;
}

final class ForgotPasswordRequested extends AuthEvent {
  const ForgotPasswordRequested({
    required this.context,
    required this.email,
  });

  final BuildContext context;
  final String email;
}

sealed class AuthState {
  const AuthState();

  bool get isLoading => this is AuthLoading;
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSuccess extends AuthState {
  const AuthSuccess();
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.failure);
  final Failure failure;
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository repository})
      : _repository = repository,
        super(const AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<ForgotPasswordRequested>(_onForgotPasswordRequested);
  }

  final AuthRepository _repository;

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result =
        await _repository.login(email: event.email, password: event.password);

    result.fold(
      (failure) {
        emit(AuthFailure(failure));
        if (event.context.mounted) {
          showToast(event.context, message: failure.message, status: 'error');
        }
      },
      (_) {
        emit(const AuthSuccess());
        if (event.context.mounted) {
          event.context.go(AppRoutes.home);
        }
      },
    );
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _repository.signUp(
      name: event.name,
      email: event.email,
      password: event.password,
    );

    result.fold(
      (failure) {
        emit(AuthFailure(failure));
        if (event.context.mounted) {
          showToast(event.context, message: failure.message, status: 'error');
        }
      },
      (_) {
        emit(const AuthSuccess());
        if (event.context.mounted) {
          event.context.go(AppRoutes.home);
        }
      },
    );
  }

  Future<void> _onForgotPasswordRequested(
    ForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _repository.forgotPassword(email: event.email);

    result.fold(
      (failure) {
        emit(AuthFailure(failure));
        if (event.context.mounted) {
          showToast(event.context, message: failure.message, status: 'error');
        }
      },
      (_) {
        emit(const AuthSuccess());
        if (event.context.mounted) {
          showToast(
            event.context,
            message: 'Password reset link sent successfully',
            status: 'success',
          );
        }
        if (event.context.mounted) {
          event.context.go(AppRoutes.login);
        }
      },
    );
  }
}
