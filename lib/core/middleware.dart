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
