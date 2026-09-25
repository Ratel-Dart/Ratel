import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import '../support/http_probe.dart';

void main() {
  Route route(String path, {bool isProtected = false}) => Route(
        path: path,
        method: 'GET',
        isProtected: isProtected,
        handler: (_) async => Response.json(data: {'path': path}),
      );

  RatelRegistry registry({
    bool protectRoute = false,
    bool protectSocket = false,
  }) =>
      RatelRegistry()
        ..register(route('/health'))
        ..register(route('/admin', isProtected: protectRoute))
        ..registerSocket(
          '/chat',
          (socket, ctx) async {
            socket.add('hello ${ctx.claims?['sub']}');
            await socket.close();
          },
          isProtected: protectSocket,
        );

  Matcher refusal(List<String> endpoints) => throwsA(
        isA<StateError>()
            .having((e) => e.message, 'message', contains(endpoints.join(', ')))
            .having((e) => e.message, 'message', contains('jwtKey'))
            .having(
              (e) => e.message,
              'message',
              contains('allowUnauthenticated: true'),
            ),
      );

  group('without a JWT key', () {
    test('refuses to start while a route is protected', () async {
      final server =
          RatelServer(port: 0, registry: registry(protectRoute: true));

      await expectLater(server.startServer(), refusal(['GET /admin']));
      expect(server.boundPort, isNull);
    });

    test('refuses to start while a socket is protected', () async {
      final server =
          RatelServer(port: 0, registry: registry(protectSocket: true));

      await expectLater(server.startServer(), refusal(['socket /chat']));
      expect(server.boundPort, isNull);
    });

    test('lists every protected route and socket', () async {
      final server = RatelServer(
        port: 0,
        registry: registry(protectRoute: true, protectSocket: true),
      );

      await expectLater(
        server.startServer(),
        refusal(['GET /admin', 'socket /chat']),
      );
    });

    test('starts when nothing is protected', () async {
      final server = RatelServer(port: 0, registry: registry());
      await server.startServer();
      addTearDown(() => server.stop(force: true));

      final (status, _) = await HttpProbe(server.boundPort!).send(
        'GET',
        '/admin',
      );
      expect(status, HttpStatus.ok);
    });

    test('refuses a protected socket registered after start', () async {
      final routes = registry();
      final server = RatelServer(port: 0, registry: routes);
      await server.startServer();
      addTearDown(() => server.stop(force: true));

      routes.registerSocket(
        '/late',
        (socket, ctx) async => socket.close(),
        isProtected: true,
      );

      await expectLater(
        WebSocket.connect('ws://127.0.0.1:${server.boundPort}/late'),
        throwsA(
          isA<WebSocketException>().having(
            (e) => e.httpStatusCode,
            'httpStatusCode',
            HttpStatus.internalServerError,
          ),
        ),
      );
    });
  });

  test('rejects an empty JWT key', () {
    expect(
      () => RatelServer(port: 0, jwtKey: '', registry: registry()),
      throwsA(
        isA<ArgumentError>().having((e) => e.name, 'name', 'jwtKey'),
      ),
    );
  });

  group('with allowUnauthenticated', () {
    final server = RatelServer(
      port: 0,
      allowUnauthenticated: true,
      registry: registry(protectRoute: true, protectSocket: true),
    );

    setUpAll(server.startServer);

    tearDownAll(() => server.stop(force: true));

    test('serves a protected route without a token', () async {
      final (status, _) = await HttpProbe(server.boundPort!).send(
        'GET',
        '/admin',
      );
      expect(status, HttpStatus.ok);
    });

    test('upgrades a protected socket without a token', () async {
      final socket =
          await WebSocket.connect('ws://127.0.0.1:${server.boundPort}/chat');
      expect(await socket.first, 'hello null');
    });
  });

  group('with a JWT key', () {
    final server = RatelServer(
      port: 0,
      jwtKey: 'secret',
      registry: registry(protectRoute: true, protectSocket: true),
    );

    setUpAll(server.startServer);

    tearDownAll(() => server.stop(force: true));

    test('refuses a protected route without a token', () async {
      final (status, _) = await HttpProbe(server.boundPort!).send(
        'GET',
        '/admin',
      );
      expect(status, HttpStatus.unauthorized);
    });
  });
}
