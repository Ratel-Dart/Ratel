import 'dart:async';

import 'request_context.dart';
import 'response.dart';

typedef ErrorHandler = FutureOr<Response> Function(
  Object error,
  StackTrace stackTrace,
  RequestContext ctx,
);
