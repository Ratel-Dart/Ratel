import '../http/request_context.dart';

typedef RouteHandler = Future<Object?> Function(RequestContext ctx);
