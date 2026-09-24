import 'dart:io';

import 'package:ratel/ratel.dart';

final class ChatController {
  Future<void> chat(WebSocket socket) async {
    socket.listen((message) => socket.add('echo: $message'));
  }

  Future<void> withContext(WebSocket socket, RequestContext ctx) async {
    socket.add('path: ${ctx.path}');
    await socket.close();
  }

  Future<Response> describe() async => Response.json(data: {'kind': 'http'});
}
