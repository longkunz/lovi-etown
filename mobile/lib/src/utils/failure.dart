import 'package:equatable/equatable.dart';

import 'error_handler.dart';

/// Domain-level failure hierarchy. Prefer exhaustive `switch` over `is` checks.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.error});

  final String message;
  final Object? error;

  /// Maps thrown objects into a typed [Failure] for railway-style APIs.
  factory Failure.fromException(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    final message = AppErrorHandler.format(error);
    return switch (error) {
      final Exception e
          when e.toString().contains('SocketException') ||
              e.toString().contains('Network') =>
        NetworkFailure(message, error: error),
      _ => UnknownFailure(message, error: error),
    };
  }

  @override
  List<Object?> get props => [message, error];

  @override
  String toString() => message;
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.error});
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.error});
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.error});
}

final class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.error});
}

final class ApiFailure extends Failure {
  const ApiFailure(
    super.message, {
    required this.statusCode,
    this.code,
    this.retryable = false,
    this.retryAfter,
    this.requestId,
    super.error,
  });

  final int statusCode;
  final String? code;
  final bool retryable;
  final Duration? retryAfter;
  final String? requestId;

  @override
  List<Object?> get props => [
        message,
        statusCode,
        code,
        retryable,
        retryAfter,
        requestId,
        error,
      ];
}

final class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'Yêu cầu đã bị hủy']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.error});
}
