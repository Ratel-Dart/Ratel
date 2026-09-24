abstract class DatabaseException implements Exception {
  const DatabaseException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}
