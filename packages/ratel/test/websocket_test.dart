import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'websocket_test.ratel.dart';

class ChatController extends RatelHandler {
  @Socket('/ws')
  Future<void> chat(WebSocket socket) async {
    socket.listen((message) => socket.add('echo: $message'));
  }

  @Socket('/ws/context')
  Future<void> withContext(WebSocket socket, RequestContext ctx) async {
    socket.add('path: ${ctx.path}');
    await socket.close();
  }

  @Get('/ws')
  Future<Response> describe() async => Response.json(data: {'kind': 'http'});
}

void main() {
  final server = RatelServer(port: 0);
  late int port;

  setUpAll(() async {
    RatelHandler.reset();
    $registerRatel();
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    await server.stop(force: true);
  });

  test('upgrades and echoes messages', () async {
    final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws');
    socket.add('hi');
    expect(await socket.first, 'echo: hi');
    await socket.close();
  });

  test('injects the request context alongside the socket', () async {
    final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws/context');
    expect(await socket.first, 'path: /ws/context');
    await socket.close();
  });

  test('refuses an upgrade on a path with no socket', () async {
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:$port/ws/missing'),
      throwsA(isA<WebSocketException>()),
    );
  });

  test('leaves plain requests on the same path to the router', () async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/ws'));
    final res = await req.close();
    expect(res.statusCode, 200);
    await res.drain<void>();
    client.close(force: true);
  });
}
