import 'dart:convert';
import 'dart:io';

import '../exceptions/ratel_serialization_exception.dart';
import '../serialization/json_codecs.dart';
import 'utf8_content_type.dart';

class Response<T> {
  static const _sseOpening = ':\n\n';

  final int statusCode;
  final T? data;
  final Map<String, String> headers;
  final String contentType;

  final List<Cookie> cookies;

  final Stream<String>? events;

  Response({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    },
    this.contentType = 'application/json; charset=utf-8',
    this.cookies = const [],
    this.events,
  });

  Response.json({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    },
  })  : contentType = 'application/json; charset=utf-8',
        cookies = const [],
        events = null;

  Response.text({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/plain; charset=utf-8',
    },
  })  : contentType = 'text/plain; charset=utf-8',
        cookies = const [],
        events = null;

  Response.html({
    this.statusCode = HttpStatus.ok,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
    },
  })  : contentType = 'text/html; charset=utf-8',
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

  static Response<Object?> from(Object? value) {
    if (value is Response) return value;
    return Response.json(
      statusCode: HttpStatus.ok,
      data: value,
    );
  }

  factory Response.sse(Stream<String> events) {
    return Response(
      statusCode: HttpStatus.ok,
      contentType: 'text/event-stream; charset=utf-8',
      headers: const {
        HttpHeaders.cacheControlHeader: 'no-cache',
        HttpHeaders.contentEncodingHeader: 'identity',
      },
      events: events,
    );
  }

  factory Response.redirect(String location, {int statusCode = 302}) {
    return Response(
      statusCode: statusCode,
      headers: {HttpHeaders.locationHeader: location},
    );
  }

  Response<T> withHeaders(Map<String, String> extra) {
    return Response<T>(
      statusCode: statusCode,
      data: data,
      headers: {...headers, ...extra},
      contentType: contentType,
      cookies: cookies,
      events: events,
    );
  }

  Response<T> withCookie(Cookie cookie) {
    return Response<T>(
      statusCode: statusCode,
      data: data,
      headers: headers,
      contentType: contentType,
      cookies: [...cookies, cookie],
      events: events,
    );
  }

  String toJson({JsonCodecs codecs = const JsonCodecs.empty()}) {
    if (data == null) return '';
    if (!_isJson) return data.toString();
    final payload = data;
    if (payload is String) return payload;
    return jsonEncode(
      payload,
      toEncodable: (object) => _toEncodable(object, codecs),
    );
  }

  static Object? _toEncodable(dynamic object, JsonCodecs codecs) {
    final codec = codecs.forType(object.runtimeType);
    if (codec != null) return codec.encodeObject(object as Object);
    if (object is DateTime) return object.toIso8601String();
    if (object is Enum) return object.name;
    if (object is Uri || object is BigInt) return object.toString();
    if (object is Iterable) return object.toList();
    try {
      return object.toJson();
    } on NoSuchMethodError {
      throw RatelSerializationException(object.runtimeType);
    }
  }

  Future<void> send(
    HttpResponse response, {
    bool includeBody = true,
    JsonCodecs codecs = const JsonCodecs.empty(),
  }) async {
    final stream = includeBody ? events : null;
    final body = includeBody && events == null ? _encodeBody(codecs) : null;

    try {
      response.statusCode = statusCode;
      headers.forEach((key, value) {
        if (!_isContentTypeHeader(key)) response.headers.set(key, value);
      });
      response.headers.set(HttpHeaders.contentTypeHeader, _contentTypeHeader);
      response.cookies.addAll(cookies);

      if (stream != null) {
        await _stream(stream, response);
      } else if (body != null && body.isNotEmpty) {
        response.add(body);
      }
    } finally {
      await response.close();
    }
  }

  bool get _isJson =>
      contentType.split(';').first.trim().toLowerCase() ==
      ContentType.json.mimeType;

  bool get _hasBytes => events == null && data is List<int>;

  String get _contentTypeHeader {
    var declared = contentType;
    headers.forEach((key, value) {
      if (_isContentTypeHeader(key)) declared = value;
    });
    return _hasBytes
        ? Utf8ContentType.forBytes(declared)
        : Utf8ContentType.forText(declared);
  }

  static bool _isContentTypeHeader(String name) =>
      name.toLowerCase() == HttpHeaders.contentTypeHeader;

  List<int> _encodeBody(JsonCodecs codecs) {
    final body = data;
    if (body is List<int>) return body;
    try {
      return utf8.encode(toJson(codecs: codecs));
    } on JsonUnsupportedObjectError {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        JsonUnsupportedObjectError(body, cause: error),
        stackTrace,
      );
    }
  }

  Future<void> _stream(Stream<String> stream, HttpResponse response) async {
    response.bufferOutput = false;
    response.add(utf8.encode(_sseOpening));
    await response.flush();
    await for (final event in stream) {
      response.add(utf8.encode('data: $event\n\n'));
      await response.flush();
    }
  }
}
