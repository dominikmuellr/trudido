/// Unified application error types for consistent error handling & logging.
enum AppErrorType {
  storageRead,
  storageWrite,
  serialization,
  deserialization,
  notFound,
  validation,
  unknown,
}

/// Simple wrapper exception carrying a type and context message.
class AppError implements Exception {
  final AppErrorType type;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError(this.type, this.message, {this.cause, this.stackTrace});

  @override
  String toString() =>
      'AppError(type: $type, message: $message, cause: $cause)';
}
