import 'dart:convert';
import 'dart:io';

import '../exceptions/exceptions.dart';
import 'serialization.dart';

class Response {
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

  Future<void> send(HttpResponse response, {bool includeBody = true}) async {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    headers.forEach((key, value) => response.headers.set(key, value));
    response.cookies.addAll(cookies);

    final stream = events;
    if (stream != null && includeBody) {
      await _stream(stream, response);
      return;
    }

    if (includeBody) {
      _writeBody(response);
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

  void _writeBody(HttpResponse response) {
    final body = data;
    if (body is List<int>) {
      response.add(body);
      return;
    }
    final responseData =
        contentType == 'application/json' ? toJson() : body.toString();
    if (responseData.isNotEmpty) {
      response.write(responseData);
    }
  }
}

const _sseOpening = ':\n\n';
