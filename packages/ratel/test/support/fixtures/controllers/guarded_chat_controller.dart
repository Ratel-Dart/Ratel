import 'dart:io';

import 'package:ratel/ratel.dart';

final class GuardedChatController {
  Future<void> greet(WebSocket socket, RequestContext ctx) async {
    socket.add('hello ${ctx.claims?['sub']}');
    await socket.close();
  }
}
