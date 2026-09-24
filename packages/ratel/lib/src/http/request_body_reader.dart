import 'dart:convert';
import 'dart:io';

import '../exceptions/bad_request_exception.dart';
import '../exceptions/payload_too_large_exception.dart';

abstract final class RequestBodyReader {
  static Future<String> readLimited(
    Stream<List<int>> stream,
    int maxBytes, {
    required int maxDrainBytes,
  }) async {
    final bytes = <int>[];
    var total = 0;
    var discarded = 0;
    var drained = true;
    await for (final chunk in stream) {
      total += chunk.length;
      if (total > maxBytes) {
        discarded += chunk.length;
        if (discarded > maxDrainBytes) {
          drained = false;
          break;
        }
        continue;
      }
      bytes.addAll(chunk);
    }
    if (total > maxBytes) {
      throw PayloadTooLargeException(
        'Request body exceeds the limit of $maxBytes bytes',
        drained ? const {} : const {HttpHeaders.connectionHeader: 'close'},
      );
    }
    return utf8.decode(bytes);
  }

  static Map<String, dynamic> decode(HttpRequest request, String body) {
    final mimeType = request.headers.contentType?.mimeType;
    if (mimeType == 'application/x-www-form-urlencoded') {
      return Map<String, dynamic>.from(Uri.splitQueryString(body));
    }
    return decodeJsonObject(body);
  }

  static Map<String, dynamic> decodeJsonObject(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw BadRequestException('Request body is not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw BadRequestException('Request body must be a JSON object');
    }
    return decoded;
  }
}
