import 'dart:io';

import '../core/request_context.dart';

typedef SocketHandler = Future<void> Function(
  WebSocket socket,
  RequestContext ctx,
);
