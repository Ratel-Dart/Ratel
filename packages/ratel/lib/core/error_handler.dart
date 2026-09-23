import 'dart:async';

import 'request_context.dart';
import 'response.dart';

/// Turns an error that no route handled into a [Response].
///
/// Receives the [error] and its [stackTrace] together with the [ctx] the
/// request was dispatched with, so the response can depend on the route, the
/// path or the authenticated claims.
typedef ErrorHandler = FutureOr<Response> Function(
  Object error,
  StackTrace stackTrace,
  RequestContext ctx,
);
