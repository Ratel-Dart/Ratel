import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _ChatController extends RatelHandler {
  @Socket('/ws')
  Future<void> chat(WebSocket socket) async {
    socket.listen((message) => socket.add('echo: $message'));
  }
}

void main() {
  final server = RatelServer(port: 0, handlers: [_ChatController]);
  late int port;

  setUpAll(() async {
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    await server.stop(force: true);
  });

  test('upgrades and echoes messages over a WebSocket', () async {
    final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws');
    socket.add('hi');
    final reply = await socket.first;
    expect(reply, 'echo: hi');
    await socket.close();
  });
}
