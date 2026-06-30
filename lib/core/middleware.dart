import 'dart:io';

import '../exceptions/exceptions.dart';
import '../jwt.dart';
import 'request_context.dart';
import 'response.dart';

/// Calls the next middleware (or the route handler) in the pipeline.
typedef Next = Future<Response> Function();

/// A request interceptor. Receives the [RequestContext] and a [Next] callback;
/// it may short-circuit by returning a [Response] without calling [next], or
/// call `next()` and post-process the downstream response.
typedef Middleware = Future<Response> Function(RequestContext ctx, Next next);

/// Authentication middleware: when the matched route is protected, validates the
/// bearer token, stores the [RequestContext.claims], and enforces any required
/// roles. Throws [UnauthorizedException] (401) or [ForbiddenException] (403).
///
/// [rolesClaim] names the claim that holds the caller's roles (a string or a
/// list of strings).
Middleware jwtAuthMiddleware(
  JwtAuthMiddleware auth, {
  String rolesClaim = 'roles',
}) {
  return (ctx, next) async {
    final route = ctx.route;
    if (route != null && route.isProtected) {
      final claims = await auth.validate(ctx.request);
      if (claims == null) {
        throw const UnauthorizedException('Invalid or missing token');
      }
      ctx.claims = claims;
      if (route.requiredRoles.isNotEmpty) {
        final held = _rolesFrom(claims[rolesClaim]);
        final allowed = route.requiredRoles.any(held.contains);
        if (!allowed) {
          throw const ForbiddenException('Insufficient role');
        }
      }
    }
    return next();
  };
}

Set<String> _rolesFrom(dynamic value) {
  if (value is String) return {value};
  if (value is Iterable) return value.map((e) => e.toString()).toSet();
  return const {};
}

/// CORS middleware. Answers preflight `OPTIONS` requests with `204` and the
/// configured headers, and decorates every other response with the same
/// `Access-Control-*` headers.
Middleware corsMiddleware({
  List<String> allowedOrigins = const ['*'],
  List<String> allowedMethods = const [
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'OPTIONS',
  ],
  List<String> allowedHeaders = const ['Content-Type', 'Authorization'],
  bool allowCredentials = false,
}) {
  final headers = <String, String>{
    'Access-Control-Allow-Origin': allowedOrigins.join(', '),
    'Access-Control-Allow-Methods': allowedMethods.join(', '),
    'Access-Control-Allow-Headers': allowedHeaders.join(', '),
    if (allowCredentials) 'Access-Control-Allow-Credentials': 'true',
  };
  return (ctx, next) async {
    if (ctx.method == 'OPTIONS') {
      return Response(statusCode: HttpStatus.noContent, headers: headers);
    }
    final response = await next();
    return response.withHeaders(headers);
  };
}

/// Adds a baseline set of security headers to every response.
Middleware securityHeadersMiddleware({
  bool hsts = false,
  String frameOptions = 'DENY',
  String? contentSecurityPolicy,
}) {
  final headers = <String, String>{
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': frameOptions,
    'Referrer-Policy': 'no-referrer',
    if (hsts)
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    if (contentSecurityPolicy != null)
      'Content-Security-Policy': contentSecurityPolicy,
  };
  return (ctx, next) async {
    final response = await next();
    return response.withHeaders(headers);
  };
}

/// Fixed-window rate limiting per client IP: at most [maxRequests] requests per
/// [window]. Once exceeded, requests get a `429` with a `Retry-After` header
/// until the window rolls over. Useful to blunt brute-force and flood attacks;
/// place it early in the pipeline (before auth).
Middleware rateLimitMiddleware({
  int maxRequests = 100,
  Duration window = const Duration(minutes: 1),
}) {
  final windows = <String, _RateWindow>{};
  return (ctx, next) async {
    final ip = ctx.request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final now = DateTime.now();

    // Opportunistically evict expired windows so the map cannot grow forever.
    if (windows.length > 10000) {
      windows.removeWhere((_, w) => now.isAfter(w.resetAt));
    }

    final current = windows[ip];
    if (current == null || now.isAfter(current.resetAt)) {
      windows[ip] = _RateWindow(now.add(window), 1);
    } else {
      current.count++;
      if (current.count > maxRequests) {
        final retryAfter = current.resetAt.difference(now).inSeconds;
        throw TooManyRequestsException(
          retryAfterSeconds: retryAfter < 1 ? 1 : retryAfter,
        );
      }
    }
    return next();
  };
}

class _RateWindow {
  final DateTime resetAt;
  int count;
  _RateWindow(this.resetAt, this.count);
}

/// Serves files from [directory] for requests whose path starts with
/// [urlPrefix]. Non-GET requests, non-matching paths, and missing files fall
/// through to the next handler. Path traversal is blocked by resolving the real
/// file path and ensuring it stays inside [directory].
Middleware staticFiles({
  required String directory,
  String urlPrefix = '/',
}) {
  final root = Directory(directory);
  String? rootReal;
  return (ctx, next) async {
    if (ctx.method != 'GET' || !ctx.path.startsWith(urlPrefix)) {
      return next();
    }
    rootReal ??= await root.resolveSymbolicLinks();

    var relative = ctx.path.substring(urlPrefix.length);
    if (relative.startsWith('/')) relative = relative.substring(1);
    if (relative.isEmpty) return next();

    final file = File('${root.path}/$relative');
    if (!await file.exists()) return next();

    final real = await file.resolveSymbolicLinks();
    final sep = Platform.pathSeparator;
    if (real != rootReal && !real.startsWith('$rootReal$sep')) {
      throw const NotFoundException();
    }

    final bytes = await file.readAsBytes();
    return Response.bytes(statusCode: 200, data: bytes).withHeaders(
      {HttpHeaders.contentTypeHeader: _mimeType(file.path)},
    );
  };
}

String _mimeType(String path) {
  final dot = path.lastIndexOf('.');
  final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
  return _mimeTypes[ext] ?? 'application/octet-stream';
}

const _mimeTypes = <String, String>{
  'html': 'text/html; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'js': 'application/javascript; charset=utf-8',
  'json': 'application/json; charset=utf-8',
  'txt': 'text/plain; charset=utf-8',
  'svg': 'image/svg+xml',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'ico': 'image/x-icon',
  'pdf': 'application/pdf',
  'wasm': 'application/wasm',
};
