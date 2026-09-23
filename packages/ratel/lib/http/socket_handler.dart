import 'dart:io';

import '../core/request_context.dart';

/// Handles one accepted WebSocket connection.
///
/// Receives the upgraded [socket] and the [ctx] of the request that was
/// upgraded. The connection closes when the handler's future completes and the
/// socket is closed by either end.
typedef SocketHandler = Future<void> Function(
  WebSocket socket,
  RequestContext ctx,
);
