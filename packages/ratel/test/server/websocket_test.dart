import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/chat_controller_definition.dart';

void main() {
  final server = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(controllers: [ChatControllerDefinition.value]),
    ),
  );
  late int port;

  setUpAll(() async {
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
