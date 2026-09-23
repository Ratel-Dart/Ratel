import 'dart:io';

import '../annotations/annotations.dart';
import 'ratel_registry.dart';

/// Per-request state shared between middleware and the route handler.
///
/// Carries the raw [request], the matched [route] (null until matched / when no
/// route matches), any extracted [pathParams], the authenticated [claims] (set
/// by the auth middleware), the [registry] the serving server runs with, and a
/// free-form [state] bag for custom middleware.
class RequestContext {
  /// The raw incoming request.
  final HttpRequest request;

  /// The registry the serving server runs with. Generated handlers read the
  /// request body limit from it, so the limit belongs to the server that
  /// accepted the request rather than to the process.
  final RatelRegistry registry;

  /// The route matched for this request, or null when none matched.
  Route? route;

  /// Path parameters captured from `:name` segments of the matched route.
  Map<String, String> pathParams;

  /// Authenticated JWT claims, set by the auth middleware on protected routes.
  Map<String, dynamic>? claims;

  /// Arbitrary per-request values that middleware can attach for downstream use.
  final Map<String, Object?> state = {};

  /// Creates a context for [request], defaulting to the ambient registry.
  RequestContext(
    this.request, {
    this.pathParams = const {},
    RatelRegistry? registry,
  }) : registry = registry ?? RatelRegistry.current;

  /// The request path.
  String get path => request.uri.path;

  /// The request HTTP method (uppercased by `dart:io`).
  String get method => request.method;
}
