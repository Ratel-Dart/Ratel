import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

import '../exceptions/bad_request_exception.dart';
import '../exceptions/payload_too_large_exception.dart';
import 'multipart_data.dart';
import 'uploaded_file.dart';

abstract final class MultipartParser {
  static Future<MultipartData> read(HttpRequest request, int maxBytes) async {
    final contentType = request.headers.contentType;
    if (contentType?.mimeType != 'multipart/form-data') {
      throw const BadRequestException(
        'Request body must be multipart/form-data',
      );
    }

    final boundary = contentType!.parameters['boundary'];
    if (boundary == null) {
      throw const BadRequestException('Multipart body declares no boundary');
    }

    final fields = <String, String>{};
    final files = <UploadedFile>[];
    var total = 0;

    await for (final part in MimeMultipartTransformer(boundary).bind(request)) {
      final disposition = part.headers['content-disposition'] ?? '';
      final name = _dispositionValue(disposition, 'name');
      final filename = _dispositionValue(disposition, 'filename');

      final bytes = <int>[];
      await for (final chunk in part) {
        total += chunk.length;
        if (total > maxBytes) {
          throw PayloadTooLargeException(
            'Multipart body exceeds the limit of $maxBytes bytes',
          );
        }
        bytes.addAll(chunk);
      }

      if (filename != null) {
        files.add(UploadedFile(
          field: name ?? '',
          filename: filename,
          contentType: part.headers['content-type'],
          bytes: bytes,
        ));
      } else if (name != null) {
        fields[name] = utf8.decode(bytes);
      }
    }

    return MultipartData(fields: fields, files: files);
  }

  static String? _dispositionValue(String disposition, String key) {
    final pattern = RegExp(r'(?:^|;)\s*' + RegExp.escape(key) + r'="([^"]*)"');
    return pattern.firstMatch(disposition)?.group(1);
  }
}
