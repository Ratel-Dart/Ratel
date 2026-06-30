import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

import '../exceptions/exceptions.dart';

/// A file received in a `multipart/form-data` request.
class UploadedFile {
  /// The form field name this file was uploaded under.
  final String field;

  /// The client-provided file name, if any.
  final String? filename;

  /// The part's declared content type, if any.
  final String? contentType;

  /// The raw file bytes.
  final List<int> bytes;

  /// Creates an uploaded file descriptor.
  UploadedFile({
    required this.field,
    this.filename,
    this.contentType,
    required this.bytes,
  });
}

/// A parsed `multipart/form-data` body: text [fields] and uploaded [files].
/// Inject it by declaring a handler parameter typed `MultipartData`.
class MultipartData {
  /// Text form fields keyed by name.
  final Map<String, String> fields;

  /// Uploaded files, in the order received.
  final List<UploadedFile> files;

  /// Creates parsed multipart data.
  MultipartData({this.fields = const {}, this.files = const []});

  /// The first uploaded file for [field], or null when absent.
  UploadedFile? file(String field) {
    for (final file in files) {
      if (file.field == field) return file;
    }
    return null;
  }
}

/// Parses a `multipart/form-data` [request] body into a [MultipartData],
/// enforcing a [maxBytes] cap across all parts (413 when exceeded).
Future<MultipartData> parseMultipart(
  HttpRequest request,
  ContentType contentType,
  int maxBytes,
) async {
  final boundary = contentType.parameters['boundary'];
  if (boundary == null) {
    throw const BadRequestException('Missing multipart boundary');
  }

  final fields = <String, String>{};
  final files = <UploadedFile>[];
  var total = 0;

  final parts = MimeMultipartTransformer(boundary).bind(request);
  await for (final part in parts) {
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

String? _dispositionValue(String disposition, String key) {
  final match = RegExp('$key="([^"]*)"').firstMatch(disposition);
  return match?.group(1);
}
