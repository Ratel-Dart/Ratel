import 'dart:io';

import '../annotations/annotations.dart';

/// Per-request state shared between middleware and the route handler.
///
/// Carries the raw [request], the matched [route] (null until matched / when no
/// route matches), any extracted [pathParams], the authenticated [claims] (set
/// by the auth middleware), and a free-form [state] bag for custom middleware.
class RequestContext {
  /// The raw incoming request.
  final HttpRequest request;

  /// The route matched for this request, or null when none matched.
  Route? route;

  /// Path parameters extracted from the URL (populated once routing supports
  /// them; empty today).
  final Map<String, String> pathParams;

  /// Authenticated JWT claims, set by the auth middleware on protected routes.
  Map<String, dynamic>? claims;

  /// Arbitrary per-request values that middleware can attach for downstream use.
  final Map<String, Object?> state = {};

  /// Creates a context for [request].
  RequestContext(this.request, {this.pathParams = const {}});

  /// The request path.
  String get path => request.uri.path;

  /// The request HTTP method (uppercased by `dart:io`).
  String get method => request.method;
}
