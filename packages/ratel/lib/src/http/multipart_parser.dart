import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

import '../exceptions/bad_request_exception.dart';
import '../exceptions/payload_too_large_exception.dart';
import 'multipart_data.dart';
import 'uploaded_file.dart';

abstract final class MultipartParser {
  static Future<MultipartData> read(
    HttpRequest request,
    int maxBytes, {
    required int maxDrainBytes,
  }) async {
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

    final result = Completer<MultipartData>();
    final fields = <String, String>{};
    final files = <UploadedFile>[];
    final input = StreamController<List<int>>(sync: true);
    late final StreamSubscription<List<int>> source;
    var total = 0;
    var discarded = 0;
    var malformed = false;
    var received = false;

    void reject(Object error, [StackTrace? stackTrace]) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    }

    void fail(Object error, StackTrace stackTrace) {
      if (error is! MimeMultipartException && error is! FormatException) {
        reject(error, stackTrace);
        return;
      }
      if (malformed) return;
      malformed = true;
      if (received) reject(_malformed(drained: true), stackTrace);
    }

    bool discard(List<int> chunk) {
      discarded += chunk.length;
      if (discarded <= maxDrainBytes) return true;
      unawaited(source.cancel());
      return false;
    }

    void collect(MimeMultipart part) {
      final disposition = part.headers['content-disposition'] ?? '';
      final name = _dispositionValue(disposition, 'name');
      final filename = _dispositionValue(disposition, 'filename');
      final bytes = <int>[];
      part.listen(
        (chunk) {
          total += chunk.length;
          if (total <= maxBytes) {
            bytes.addAll(chunk);
          } else if (!discard(chunk)) {
            reject(_tooLarge(maxBytes, drained: false));
          }
        },
        onError: fail,
        onDone: () {
          if (total > maxBytes) return;
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
        },
      );
    }

    void finish() {
      if (total > maxBytes) {
        reject(_tooLarge(maxBytes, drained: true));
      } else if (!result.isCompleted) {
        result.complete(MultipartData(fields: fields, files: files));
      }
    }

    void forward(List<int> chunk) {
      if (!malformed) {
        input.add(chunk);
      } else if (!discard(chunk)) {
        reject(_malformed(drained: false));
      }
    }

    void close() {
      received = true;
      if (malformed) {
        reject(_malformed(drained: true));
      } else {
        input.close();
      }
    }

    runZonedGuarded(() {
      MimeMultipartTransformer(boundary)
          .bind(input.stream)
          .listen(collect, onError: fail, onDone: finish);
      source = request.listen(
        forward,
        onError: (Object error, StackTrace stackTrace) =>
            reject(malformed ? _malformed(drained: false) : error, stackTrace),
        onDone: close,
      );
      input
        ..onPause = () {
          if (!malformed) source.pause();
        }
        ..onResume = () {
          if (!malformed) source.resume();
        };
    }, fail);
    return result.future;
  }

  static PayloadTooLargeException _tooLarge(
    int maxBytes, {
    required bool drained,
  }) =>
      PayloadTooLargeException(
        'Multipart body exceeds the limit of $maxBytes bytes',
        drained ? const {} : const {HttpHeaders.connectionHeader: 'close'},
      );

  static BadRequestException _malformed({required bool drained}) =>
      BadRequestException(
        'Malformed multipart body',
        drained ? const {} : const {HttpHeaders.connectionHeader: 'close'},
      );

  static String? _dispositionValue(String disposition, String key) {
    final pattern = RegExp(r'(?:^|;)\s*' + RegExp.escape(key) + r'="([^"]*)"');
    return pattern.firstMatch(disposition)?.group(1);
  }
}
