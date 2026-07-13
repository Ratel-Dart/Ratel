import 'dart:convert';
import 'dart:io';

/// An HTTP response with a [statusCode], a [data] payload, and a content type.
///
/// Use the named constructors ([Response.json], [Response.text],
/// [Response.html], [Response.bytes]) for a specific representation, or
/// [Response.from] to wrap an arbitrary handler return value as JSON.
class Response {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
  final String contentType;

  Response({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
    this.contentType = 'application/json',
  });

  Response.json({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
  }) : contentType = 'application/json';

  Response.text({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/plain',
    },
  }) : contentType = 'text/plain';

  Response.html({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/html',
    },
  }) : contentType = 'text/html';

  Response.bytes({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/octet-stream',
    },
  }) : contentType = 'application/octet-stream';

  static Response from(dynamic value) {
    if (value is Response) return value;
    return Response.json(
      statusCode: HttpStatus.ok,
      data: value,
    );
  }

  /// Builds a redirect response to [location] (default `302 Found`; use `301`
  /// for a permanent redirect).
  factory Response.redirect(String location, {int statusCode = 302}) {
    return Response(
      statusCode: statusCode,
      headers: {HttpHeaders.locationHeader: location},
    );
  }

  /// Returns a copy of this response with [extra] headers merged in (extra
  /// values win on conflict). Useful for middleware that decorates responses,
  /// e.g. CORS or security headers.
  Response withHeaders(Map<String, String> extra) {
    return Response(
      statusCode: statusCode,
      data: data,
      headers: {...headers, ...extra},
      contentType: contentType,
    );
  }

  /// Serializes [data] to a JSON string.
  ///
  /// Primitives, `List`s and `Map`s encode natively; other objects are expected
  /// to provide a `toJson()` method (generated for `@Json` classes) and fall
  /// back to `toString()` otherwise.
  String toJson() {
    if (data == null) return '';
    if (contentType != 'application/json') return data.toString();
    final payload = data;
    if (payload is String) return payload;
    return jsonEncode(payload, toEncodable: _toEncodable);
  }

  static Object? _toEncodable(dynamic object) {
    try {
      return object.toJson();
    } on NoSuchMethodError {
      return object.toString();
    }
  }

  void send(HttpResponse response) {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    headers.forEach((key, value) => response.headers.set(key, value));
    final body = data;
    if (body is List<int>) {
      response.add(body);
    } else {
      final responseData =
          contentType == 'application/json' ? toJson() : body.toString();
      if (responseData.isNotEmpty) {
        response.write(responseData);
      }
    }
    response.close();
  }
}
