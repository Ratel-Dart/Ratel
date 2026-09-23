import 'dart:convert';
import 'dart:io';

import '../exceptions/exceptions.dart';
import 'serialization.dart';

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

  /// Cookies sent as `Set-Cookie` headers. Attach one with [withCookie].
  final List<Cookie> cookies;

  Response({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
    this.contentType = 'application/json',
    this.cookies = const [],
  });

  Response.json({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
  })  : contentType = 'application/json',
        cookies = const [];

  Response.text({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/plain',
    },
  })  : contentType = 'text/plain',
        cookies = const [];

  Response.html({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/html',
    },
  })  : contentType = 'text/html',
        cookies = const [];

  Response.bytes({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/octet-stream',
    },
  })  : contentType = 'application/octet-stream',
        cookies = const [];

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
      cookies: cookies,
    );
  }

  /// Returns a copy of this response with [cookie] appended to [cookies].
  ///
  /// Build the `dart:io` [Cookie] with the flags the response needs
  /// (`httpOnly`, `secure`, `sameSite`, `maxAge`, ...).
  Response withCookie(Cookie cookie) {
    return Response(
      statusCode: statusCode,
      data: data,
      headers: headers,
      contentType: contentType,
      cookies: [...cookies, cookie],
    );
  }

  /// Serializes [data] to a JSON string.
  ///
  /// Primitives, `List`s and `Map`s encode natively. `@Json` classes encode
  /// through their generated encoder; `DateTime`, `Enum`, `Uri` and `BigInt`
  /// have built-in representations, and any other object must expose a
  /// `toJson()` method. Anything else throws a [RatelSerializationException]
  /// naming the offending type.
  String toJson() {
    if (data == null) return '';
    if (contentType != 'application/json') return data.toString();
    final payload = data;
    if (payload is String) return payload;
    return jsonEncode(payload, toEncodable: _toEncodable);
  }

  static Object? _toEncodable(dynamic object) {
    final encode = RatelJson.encoderFor(object.runtimeType);
    if (encode != null) return encode(object as Object);
    if (object is DateTime) return object.toIso8601String();
    if (object is Enum) return object.name;
    if (object is Uri || object is BigInt) return object.toString();
    try {
      return object.toJson();
    } on NoSuchMethodError {
      throw RatelSerializationException(object.runtimeType);
    }
  }

  void send(HttpResponse response) {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    headers.forEach((key, value) => response.headers.set(key, value));
    response.cookies.addAll(cookies);
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
