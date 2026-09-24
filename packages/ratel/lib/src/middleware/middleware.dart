import '../http/request_context.dart';
import '../http/response.dart';
import 'next.dart';

typedef Middleware = Future<Response> Function(RequestContext ctx, Next next);
