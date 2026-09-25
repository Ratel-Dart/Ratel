import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/greeting_codec.dart';
import '../support/fixtures/controllers/greeter_controller.dart';
import '../support/fixtures/definitions/binding_controller_definition.dart';
import '../support/fixtures/definitions/greeter_controller_definition.dart';
import '../support/http_probe.dart';

void main() {
  group('a manifest bound into a registry', () {
    late RatelServer server;
    late HttpProbe probe;

    setUpAll(() async {
      server = RatelServer(
        port: 0,
        jwtKey: 'secret',
        registry: RatelRegistry.fromManifest(
          const RatelManifest(
            controllers: [BindingControllerDefinition.value],
            jsonCodecs: [GreetingCodec.definition],
          ),
        ),
      );
      await server.startServer();
      probe = HttpProbe(server.boundPort!);
    });

    tearDownAll(() => server.stop(force: true));

    test('binds path, query, header and cookie parameters', () async {
      final (status, body) = await probe.send(
        'GET',
        '/items/7?filter=new',
        headers: {'X-Trace': 'abc'},
        cookies: [Cookie('session', 's1')],
      );
      expect(status, 200);
      expect(jsonDecode(body), {
        'id': 7,
        'filter': 'new',
        'trace': 'abc',
        'session': 's1',
      });
    });

    test('rejects a path parameter that does not coerce', () async {
      final (status, _) = await probe.send('GET', '/items/seven');
      expect(status, 400);
    });

    test('injects the request context', () async {
      final (_, body) = await probe.send('GET', '/me');
      expect(jsonDecode(body), {'path': '/me'});
    });

    test('decodes a JSON body through its codec and encodes the result',
        () async {
      final (status, body) = await probe.send(
        'POST',
        '/echo',
        headers: {'content-type': 'application/json'},
        body: utf8.encode('{"message":"hi"}'),
      );
      expect(status, 200);
      expect(jsonDecode(body), {'message': 'hi'});
    });

    test('decodes a form-encoded body', () async {
      final (_, body) = await probe.send(
        'POST',
        '/echo',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: utf8.encode('message=hi'),
      );
      expect(jsonDecode(body), {'message': 'hi'});
    });

    test('feeds a body from multipart fields alongside the files', () async {
      const boundary = 'ratel-boundary';
      final (status, body) = await probe.send(
        'POST',
        '/upload',
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: utf8.encode(
          '--$boundary\r\n'
          'content-disposition: form-data; name="message"\r\n\r\n'
          'hi\r\n'
          '--$boundary\r\n'
          'content-disposition: form-data; name="avatar"; filename="a.txt"\r\n'
          'content-type: text/plain\r\n\r\n'
          'bytes\r\n'
          '--$boundary--\r\n',
        ),
      );
      expect(status, 200);
      expect(jsonDecode(body), {'files': 1, 'message': 'hi'});
    });

    test('hands a socket and the context to a socket route', () async {
      final socket =
          await WebSocket.connect('ws://localhost:${server.boundPort}/ws');
      expect(await socket.first, 'hello /ws');
    });

    test('keeps only request parameters and the body type on the route', () {
      final routes = {
        for (final route in server.registry.routes)
          '${route.method} ${route.path}': route,
      };
      expect(
        routes['GET /items/:id']!.parameters.map((p) => p.location),
        [
          ParameterLocation.path,
          ParameterLocation.query,
          ParameterLocation.header,
          ParameterLocation.cookie,
        ],
      );
      expect(routes['POST /echo']!.bodyType, 'Greeting');
      expect(routes['POST /upload']!.parameters, isEmpty);
      expect(routes['GET /plain']!.isProtected, isTrue);
      expect(routes['GET /plain']!.requiredRoles, ['admin']);
    });
  });

  group('a controller without a no-argument constructor', () {
    setUp(() => Injector.ambient = Injector.scoped());

    RatelServer greeterServer() => RatelServer(
          port: 0,
          registry: RatelRegistry.fromManifest(
            const RatelManifest(
              controllers: [GreeterControllerDefinition.value],
            ),
          ),
        );

    test('is built by the injector', () async {
      Injector().put<GreeterController>(() => GreeterController('ahoy'));
      final server = greeterServer();
      await server.startServer();
      addTearDown(() => server.stop(force: true));

      final (status, body) =
          await HttpProbe(server.boundPort!).send('GET', '/greet');
      expect(status, 200);
      expect(body, 'ahoy');
    });

    test('stops startServer when nothing can build it', () async {
      final server = greeterServer();

      await expectLater(server.startServer(), throwsStateError);
      expect(server.boundPort, isNull);
    });
  });
}
