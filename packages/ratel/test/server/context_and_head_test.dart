import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/session_controller_definition.dart';

void main() {
  final server = RatelServer(
    port: 0,
    jwtKey: 'secret',
    registry: RatelRegistry.fromManifest(
      const RatelManifest(controllers: [SessionControllerDefinition.value]),
    ),
  );
  final client = HttpClient();
  late int port;

  setUpAll(() async {
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
  });

  Future<HttpClientResponse> send(String method, String path,
      {String? token}) async {
    final req =
        await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    return req.close();
  }

  test('injects the RequestContext into a handler', () async {
    final token = JWT({'sub': 'u1'})
        .sign(SecretKey('secret'), expiresIn: const Duration(hours: 1));
    final res = await send('GET', '/me', token: token);
    expect(res.statusCode, 200);
    expect(
      jsonDecode(await res.transform(utf8.decoder).join()),
      {'sub': 'u1', 'path': '/me'},
    );
  });

  test('answers HEAD from the GET route, with no body', () async {
    final head = await send('HEAD', '/ping');
    expect(head.statusCode, 200);
    expect(head.headers.contentType?.mimeType, 'application/json');
    expect(await head.transform(utf8.decoder).join(), isEmpty);
  });

  test('prefers an explicit HEAD route over the GET fallback', () async {
    final res = await send('HEAD', '/explicit');
    expect(res.statusCode, HttpStatus.noContent);
    expect(res.headers.value('x-kind'), 'head');
    await res.drain<void>();
  });

  test('still answers 404 for a HEAD on an unknown path', () async {
    final res = await send('HEAD', '/nowhere');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });
}
