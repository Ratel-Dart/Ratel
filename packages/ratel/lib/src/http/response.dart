import 'dart:convert';
import 'dart:io';

import '../exceptions/ratel_serialization_exception.dart';
import '../serialization/json_codecs.dart';

class Response {
  static const _sseOpening = ':\n\n';

  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
  final String contentType;

  final List<Cookie> cookies;

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

  factory Response.redirect(String location, {int statusCode = 302}) {
    return Response(
      statusCode: statusCode,
      headers: {HttpHeaders.locationHeader: location},
    );
  }

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
    final stream = events;
    final body = includeBody && stream == null ? _encodeBody(codecs) : null;

    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    headers.forEach((key, value) => response.headers.set(key, value));
    response.cookies.addAll(cookies);

    if (stream != null && includeBody) {
      await _stream(stream, response);
      return;
    }

    if (body is List<int>) {
      response.add(body);
    } else if (body is String && body.isNotEmpty) {
      response.write(body);
    }
    await response.close();
  }

  bool get _isJson =>
      contentType.split(';').first.trim().toLowerCase() ==
      ContentType.json.mimeType;

  Object _encodeBody(JsonCodecs codecs) {
    final body = data;
    return body is List<int> ? body : toJson(codecs: codecs);
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
