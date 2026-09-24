import 'dart:async';

import '../http/request_context.dart';
import '../http/response.dart';

typedef ErrorHandler = FutureOr<Response> Function(
  Object error,
  StackTrace stackTrace,
  RequestContext ctx,
);
