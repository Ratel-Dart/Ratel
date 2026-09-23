import 'package:source_gen/source_gen.dart';

const requestContextChecker = TypeChecker.fromUrl(
  'package:ratel/core/request_context.dart#RequestContext',
);

const multipartChecker = TypeChecker.fromUrl(
  'package:ratel/http/multipart_data.dart#MultipartData',
);

/// `WebSocket` is declared in `dart:_http` and re-exported by `dart:io`, so the
/// check covers both rather than betting on which library the SDK reports.
const webSocketChecker = TypeChecker.any([
  TypeChecker.fromUrl('dart:io#WebSocket'),
  TypeChecker.fromUrl('dart:_http#WebSocket'),
]);
