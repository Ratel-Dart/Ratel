import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/guarded_chat_controller_definition.dart';

void main() {
  RatelRegistry registry() => RatelRegistry.fromManifest(
        const RatelManifest(
          controllers: [GuardedChatControllerDefinition.value],
        ),
      );

  String tokenFor({List<String>? roles}) {
    final payload = <String, dynamic>{'sub': 'u1'};
    if (roles != null) payload['roles'] = roles;
    return JWT(payload)
        .sign(SecretKey('secret'), expiresIn: const Duration(hours: 1));
  }

  Matcher refusedWith(int status) => throwsA(
        isA<WebSocketException>().having(
          (error) => error.httpStatusCode,
          'httpStatusCode',
          status,
        ),
      );

  group('with a JWT key', () {
    final server = RatelServer(
      port: 0,
      jwtKey: 'secret',
      logToConsole: false,
      registry: registry(),
    );
    late int port;

    Future<WebSocket> connect(String path, {String? token}) =>
        WebSocket.connect(
          'ws://127.0.0.1:$port$path',
          headers: {
            if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        );

    setUpAll(() async {
      await server.startServer();
      port = server.boundPort!;
    });

    tearDownAll(() async {
      await server.stop(force: true);
    });

    test('upgrades an unprotected socket without a token', () async {
      final socket = await connect('/ws/open');
      expect(await socket.first, 'hello null');
    });

    test('refuses a protected socket without a token with 401', () async {
      await expectLater(connect('/ws/member'), refusedWith(401));
    });

    test('refuses a protected socket with an invalid token with 401', () async {
      await expectLater(
        connect('/ws/member', token: 'not-a-token'),
        refusedWith(401),
      );
    });

    test('upgrades a protected socket with a valid token and its claims',
        () async {
      final socket = await connect('/ws/member', token: tokenFor());
      expect(await socket.first, 'hello u1');
    });

    test('refuses a role-restricted socket without the role with 403',
        () async {
      await expectLater(
        connect('/ws/admin', token: tokenFor(roles: ['user'])),
        refusedWith(403),
      );
    });

    test('upgrades a role-restricted socket with the role', () async {
      final socket =
          await connect('/ws/admin', token: tokenFor(roles: ['admin']));
      expect(await socket.first, 'hello u1');
    });
  });

  group('without a JWT key', () {
    test('refuses to start while a socket is protected', () async {
      final server = RatelServer(port: 0, registry: registry());

      await expectLater(
        server.startServer(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('socket /ws/member, socket /ws/admin'),
          ),
        ),
      );
      expect(server.boundPort, isNull);
    });
  });

  group('with allowUnauthenticated', () {
    final server = RatelServer(
      port: 0,
      allowUnauthenticated: true,
      registry: registry(),
    );
    late int port;

    setUpAll(() async {
      await server.startServer();
      port = server.boundPort!;
    });

    tearDownAll(() async {
      await server.stop(force: true);
    });

    test('upgrades a protected socket without checking a token', () async {
      final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws/member');
      expect(await socket.first, 'hello null');
    });
  });
}
