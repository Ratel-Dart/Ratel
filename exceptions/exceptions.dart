class HttpRequestException implements Exception {
  final String message;
  final Uri uri;
  final String? method;

  HttpRequestException(this.message, {required this.uri, this.method});

  @override
  String toString() {
    return 'HttpRequestException: $message (Method: $method, URI: $uri)';
  }
}

class HttpResponseException implements Exception {
  final String message;
  final int statusCode;
  final Uri uri;
  final String? method;

  HttpResponseException(this.message,
      {required this.statusCode, required this.uri, this.method});

  @override
  String toString() {
    return 'HttpResponseException: $message (StatusCode: $statusCode, Method: $method, URI: $uri)';
  }
}

class JsonDecodingException implements Exception {
  final String message;
  final String body;

  JsonDecodingException(this.message, {required this.body});

  @override
  String toString() {
    return 'JsonDecodingException: $message (Body: $body)';
  }
}
