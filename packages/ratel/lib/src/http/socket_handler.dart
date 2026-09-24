import 'dart:io';

import 'request_context.dart';

typedef SocketHandler = Future<void> Function(
  WebSocket socket,
  RequestContext ctx,
);
