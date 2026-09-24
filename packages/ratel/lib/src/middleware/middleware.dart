import 'dart:io';

import '../auth/jwt_validator.dart';
import '../exceptions/exceptions.dart';
import '../http/request_context.dart';
import '../http/response.dart';

typedef Next = Future<Response> Function();

typedef Middleware = Future<Response> Function(RequestContext ctx, Next next);

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

Middleware rateLimitMiddleware({
  int maxRequests = 100,
  Duration window = const Duration(minutes: 1),
}) {
  final windows = <String, _RateWindow>{};
  return (ctx, next) async {
    final ip = ctx.request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final now = DateTime.now();

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
