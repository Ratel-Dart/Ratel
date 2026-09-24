class HttpStatusException implements Exception {
  const HttpStatusException(
    this.statusCode,
    this.message, {
    this.headers = const {},
  });

  final int statusCode;
  final String message;
  final Map<String, String> headers;

  @override
  String toString() => 'HttpStatusException($statusCode): $message';
}
