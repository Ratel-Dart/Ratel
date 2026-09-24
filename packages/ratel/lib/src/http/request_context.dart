import 'dart:io';

import '../annotations/annotations.dart';
import '../server/ratel_registry.dart';
import 'request_limits.dart';

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
    required this.registry,
    this.limits = const RequestLimits(),
  });

  String get path => request.uri.path;

  String get method => request.method;
}
