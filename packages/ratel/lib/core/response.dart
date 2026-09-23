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

  /// Server-Sent Events to stream instead of a buffered body, set by
  /// [Response.sse].
  final Stream<String>? events;

  Response({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
    this.contentType = 'application/json',
    this.cookies = const [],
    this.events,
  });

  Response.json({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
  })  : contentType = 'application/json',
        cookies = const [],
        events = null;

  Response.text({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/plain',
    },
  })  : contentType = 'text/plain',
        cookies = const [],
        events = null;

  Response.html({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/html',
    },
  })  : contentType = 'text/html',
        cookies = const [],
        events = null;

  Response.bytes({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/octet-stream',
    },
  })  : contentType = 'application/octet-stream',
        cookies = const [],
        events = null;

  static Response from(dynamic value) {
    if (value is Response) return value;
    return Response.json(
      statusCode: HttpStatus.ok,
      data: value,
    );
  }

  /// Streams [events] as `text/event-stream` Server-Sent Events, one `data:`
  /// frame per value. The connection stays open until [events] closes.
  ///
  /// Compression is declined for the stream, since a gzip buffer would hold
  /// events back instead of delivering them as they are produced.
  factory Response.sse(Stream<String> events) {
    return Response(
      statusCode: HttpStatus.ok,
      contentType: 'text/event-stream',
      headers: const {
        HttpHeaders.cacheControlHeader: 'no-cache',
        HttpHeaders.contentEncodingHeader: 'identity',
      },
      events: events,
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
      events: events,
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
      events: events,
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

  Future<void> send(HttpResponse response) async {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    headers.forEach((key, value) => response.headers.set(key, value));
    response.cookies.addAll(cookies);

    final stream = events;
    if (stream != null) {
      await _stream(stream, response);
      return;
    }

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
    await response.close();
  }

  Future<void> _stream(Stream<String> stream, HttpResponse response) async {
    response.bufferOutput = false;
    response.write(_sseOpening);
    await response.flush();
    await for (final event in stream) {
      response.write('data: $event\n\n');
      await response.flush();
    }
    await response.close();
  }
}

/// An empty SSE comment, written as soon as the stream is subscribed so the
/// client receives the response headers without waiting for the first event.
/// Clients ignore comment lines.
const _sseOpening = ':\n\n';
