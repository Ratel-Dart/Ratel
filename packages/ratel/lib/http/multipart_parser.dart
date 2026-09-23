import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

import '../exceptions/exceptions.dart';
import 'multipart_data.dart';
import 'uploaded_file.dart';

/// Reads a `multipart/form-data` [request] body into a [MultipartData].
///
/// [maxBytes] caps the total size of every part together, so a stream of parts
/// cannot outgrow the configured request limit; going over raises
/// [PayloadTooLargeException]. A request that is not multipart, or that omits
/// the boundary, raises [BadRequestException].
Future<MultipartData> readMultipart(HttpRequest request, int maxBytes) async {
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

/// Reads the `key="value"` parameter [key] out of a `Content-Disposition`
/// header. The leading delimiter keeps `name` from matching inside `filename`.
String? _dispositionValue(String disposition, String key) {
  final pattern = RegExp(r'(?:^|;)\s*' + RegExp.escape(key) + r'="([^"]*)"');
  return pattern.firstMatch(disposition)?.group(1);
}
