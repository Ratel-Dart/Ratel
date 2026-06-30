import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import '../annotations/annotations.dart';
import 'logger.dart';

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

  /// Cookies emitted as `Set-Cookie` headers. Add one with [withCookie].
  List<Cookie> cookies = const [];

  /// When set (via [Response.sse]), the body is streamed as Server-Sent Events
  /// rather than buffered.
  Stream<String>? sseEvents;

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

  /// Streams the response body as `text/event-stream` Server-Sent Events; each
  /// value of [events] is emitted as a `data:` event. The connection stays open
  /// until [events] closes.
  factory Response.sse(Stream<String> events) {
    return Response(
      statusCode: HttpStatus.ok,
      contentType: 'text/event-stream',
      headers: const {
        HttpHeaders.contentTypeHeader: 'text/event-stream',
        HttpHeaders.cacheControlHeader: 'no-cache',
      },
    )..sseEvents = events;
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
    )
      ..cookies = cookies
      ..sseEvents = sseEvents;
  }

  /// Returns a copy of this response with [cookie] added as a `Set-Cookie`
  /// header. Build the [Cookie] (from `dart:io`) with the flags you need
  /// (`httpOnly`, `secure`, `sameSite`, ...).
  Response withCookie(Cookie cookie) {
    return Response(
      statusCode: statusCode,
      data: data,
      headers: headers,
      contentType: contentType,
    )
      ..cookies = [...cookies, cookie]
      ..sseEvents = sseEvents;
  }

  String toJson() {
    if (data == null) return '';

    if (contentType == 'application/json') {
      if (data is String) return data;

      if (data is List) {
        return jsonEncode(
          (data as List).map((item) => convertToJson(item)).toList(),
        );
      }

      if (data is Map) {
        return jsonEncode(
          (data as Map)
              .map((key, value) => MapEntry(key, convertToJson(value))),
        );
      }

      return jsonEncode(convertToJson(data));
    } else {
      return data.toString();
    }
  }

  dynamic convertToJson(dynamic obj) {
    if (obj == null) return null;
    if (obj is Map ||
        obj is List ||
        obj is String ||
        obj is num ||
        obj is bool) {
      return obj;
    }

    if (obj != null && isSerializable(obj)) {
      return _objectToJson(obj);
    }

    return obj.toString();
  }

  dynamic _objectToJson(dynamic obj) {
    final instanceMirror = reflect(obj);
    final classMirror = instanceMirror.type;
    final Map<String, dynamic> result = {};

    classMirror.declarations.forEach((symbol, decl) {
      if (decl is VariableMirror && !decl.isStatic) {
        final fieldName = MirrorSystem.getName(symbol);
        if (fieldName.startsWith('_')) return;
        try {
          var value = instanceMirror.getField(symbol).reflectee;
          result[fieldName] = convertToJson(value);
        } catch (e, stackTrace) {
          ratelLogger.warning(
            'Failed to serialize field "$fieldName"',
            e,
            stackTrace,
          );
        }
      }
    });

    classMirror.instanceMembers.forEach((symbol, methodMirror) {
      if (methodMirror.isGetter &&
          methodMirror.owner == classMirror &&
          !['hashCode', 'runtimeType', 'toString']
              .contains(MirrorSystem.getName(symbol))) {
        final getterName = MirrorSystem.getName(symbol);
        if (result.containsKey(getterName)) return;
        if (getterName.startsWith('_')) return;
        try {
          var value = instanceMirror.getField(symbol).reflectee;
          result[getterName] = convertToJson(value);
        } catch (e, stackTrace) {
          ratelLogger.warning(
            'Failed to serialize getter "$getterName"',
            e,
            stackTrace,
          );
        }
      }
    });

    return result;
  }

  bool isSerializable(Object obj) {
    final classMirror = reflectClass(obj.runtimeType);
    return classMirror.metadata
        .any((annotation) => annotation.reflectee is Json);
  }

  Future<void> send(HttpResponse response) async {
    response.statusCode = statusCode;
    response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    headers.forEach((key, value) => response.headers.set(key, value));
    for (final cookie in cookies) {
      response.cookies.add(cookie);
    }

    final events = sseEvents;
    if (events != null) {
      await for (final event in events) {
        response.write('data: $event\n\n');
        await response.flush();
      }
      await response.close();
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
}
