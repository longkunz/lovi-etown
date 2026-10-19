import 'dart:async';
import 'package:flutter_starter/src/imports/imports.dart';
import 'package:flutter_starter/src/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/src/features/auth/domain/repositories/auth_repository.dart';

/// Exhaustive session variants — prefer `switch (state)` over status enums.
sealed class SessionState {
  const SessionState();

  AppUser? get userOrNull => switch (this) {
        SessionAuthenticated(:final user) => user,
        _ => null,
      };

  bool get isUnknown => this is SessionUnknown;
  bool get isAuthenticated => this is SessionAuthenticated;
  bool get isUnauthenticated => this is SessionUnauthenticated;
}

final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.user);
  final AppUser user;
}

final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();
}

SessionState sessionFromUser(AppUser? user) => switch (user) {
      final AppUser u => SessionAuthenticated(u),
      null => const SessionUnauthenticated(),
    };

sealed class SessionEvent {
  const SessionEvent();
}

final class SessionCheckRequested extends SessionEvent {
  const SessionCheckRequested();
}

final class SessionUserChanged extends SessionEvent {
  const SessionUserChanged(this.user);
  final AppUser? user;
}

final class SessionLogoutRequested extends SessionEvent {
  const SessionLogoutRequested();
}

class SessionBloc extends Bloc<SessionEvent, SessionState>
    with StreamSubscriptionsMixin {
  SessionBloc({required AuthRepository repository})
      : _repository = repository,
        super(const SessionUnknown()) {
    on<SessionCheckRequested>(_onCheckRequested);
    on<SessionUserChanged>(_onUserChanged);
    on<SessionLogoutRequested>(_onLogoutRequested);
    add(const SessionCheckRequested());
  }

  final AuthRepository _repository;

  Future<void> _onCheckRequested(
    SessionCheckRequested event,
    Emitter<SessionState> emit,
  ) async {
    final result = await _repository.checkAuthState();
    emit(result.fold(
      (_) => const SessionUnauthenticated(),
      sessionFromUser,
    ));

    await cancelSubscriptions();
    addSubscription(
      _repository.onAuthStateChanged.listen((user) {
        add(SessionUserChanged(user));
      }),
    );
  }

  void _onUserChanged(
    SessionUserChanged event,
    Emitter<SessionState> emit,
  ) {
    emit(sessionFromUser(event.user));
  }

  Future<void> _onLogoutRequested(
    SessionLogoutRequested event,
    Emitter<SessionState> emit,
  ) async {
    await _repository.logout();
    emit(const SessionUnauthenticated());
  }

  @override
  Future<void> close() async {
    await cancelSubscriptions();
    return super.close();
  }
}
