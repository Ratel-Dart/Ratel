import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../exceptions/exceptions.dart';
import '../http/response.dart';
import 'middleware.dart';

Middleware staticFiles({
  required String directory,
  String urlPrefix = '/',
}) {
  final root = Directory(directory);
  String? rootPath;
  return (ctx, next) async {
    if (ctx.method != 'GET') return next();

    final relative = _relativePath(ctx.path, urlPrefix);
    if (relative == null || relative.isEmpty) return next();

    final resolvedRoot = rootPath ??= await _resolveRoot(root);
    if (resolvedRoot == null) return next();

    final file = File(p.joinAll([resolvedRoot, ...relative.split('/')]));
    if (!await file.exists()) return next();

    if (!p.isWithin(resolvedRoot, await file.resolveSymbolicLinks())) {
      throw const NotFoundException();
    }

    return Response(
      statusCode: HttpStatus.ok,
      data: await file.readAsBytes(),
      contentType: _contentTypeFor(file.path),
      headers: const {},
    );
  };
}

String? _relativePath(String path, String urlPrefix) {
  final prefix = urlPrefix.endsWith('/') && urlPrefix.length > 1
      ? urlPrefix.substring(0, urlPrefix.length - 1)
      : urlPrefix;
  if (prefix.isEmpty || prefix == '/') {
    return path.startsWith('/') ? path.substring(1) : path;
  }
  if (!path.startsWith(prefix)) return null;
  final rest = path.substring(prefix.length);
  if (!rest.startsWith('/')) return null;
  return rest.substring(1);
}

Future<String?> _resolveRoot(Directory root) async {
  try {
    return await root.resolveSymbolicLinks();
  } on FileSystemException {
    return null;
  }
}

const _utf8Types = {'application/javascript', 'application/json'};

String _contentTypeFor(String path) {
  final type = lookupMimeType(path) ?? 'application/octet-stream';
  if (type.startsWith('text/') || _utf8Types.contains(type)) {
    return '$type; charset=utf-8';
  }
  return type;
}
