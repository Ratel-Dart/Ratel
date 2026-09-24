import 'dart:io';

import '../annotations/annotations.dart';
import '../src/http/request_limits.dart';
import 'ratel_registry.dart';

class RequestContext {
  final HttpRequest request;

  final RatelRegistry registry;

  final RequestLimits limits;

  Route? route;

  Map<String, String> pathParams;

  Map<String, dynamic>? claims;

  final Map<String, Object?> state = {};

  RequestContext(
    this.request, {
    this.pathParams = const {},
    RatelRegistry? registry,
    this.limits = const RequestLimits(),
  }) : registry = registry ?? RatelRegistry.current;

  String get path => request.uri.path;

  String get method => request.method;
}
