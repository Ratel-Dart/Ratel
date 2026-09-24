import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/ping_controller_definition.dart';
import '../support/fixtures/definitions/widgets_controller_definition.dart';

void main() {
  const manifest = RatelManifest(
    controllers: [
      PingControllerDefinition.value,
      WidgetsControllerDefinition.value,
    ],
  );
  final listed = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(manifest),
    middlewares: [
      CorsMiddleware.create(
        allowedOrigins: ['https://a.com', 'https://b.com'],
      ),
    ],
  );
  final wildcard = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(manifest),
    middlewares: [CorsMiddleware.create()],
  );
  final client = HttpClient();

  Future<HttpClientResponse> send(
    RatelServer server,
    String method,
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.boundPort}$path'),
    );
    headers.forEach(request.headers.set);
    return request.close();
  }

  setUpAll(() async {
    await listed.startServer();
    await wildcard.startServer();
  });

  tearDownAll(() async {
    client.close(force: true);
    await listed.stop(force: true);
    await wildcard.stop(force: true);
  });

  test('echoes an allowed origin and varies on Origin', () async {
    final res = await send(
      listed,
      'GET',
      '/ping',
      headers: {'Origin': 'https://b.com'},
    );
    expect(res.statusCode, 200);
    expect(res.headers['access-control-allow-origin'], ['https://b.com']);
    expect(res.headers.value('vary'), contains('Origin'));
    await res.drain<void>();
  });

  test('sends no allow-origin for a disallowed origin', () async {
    final res = await send(
      listed,
      'GET',
      '/ping',
      headers: {'Origin': 'https://evil.com'},
    );
    expect(res.statusCode, 200);
    expect(res.headers.value('access-control-allow-origin'), isNull);
    await res.drain<void>();
  });

  test('keeps the wildcard when it is configured', () async {
    final res = await send(
      wildcard,
      'GET',
      '/ping',
      headers: {'Origin': 'https://anywhere.com'},
    );
    expect(res.headers['access-control-allow-origin'], ['*']);
    await res.drain<void>();
  });

  test('answers a preflight from an allowed origin with 204', () async {
    final res = await send(
      listed,
      'OPTIONS',
      '/ping',
      headers: {
        'Origin': 'https://a.com',
        'Access-Control-Request-Method': 'GET',
      },
    );
    expect(res.statusCode, 204);
    expect(res.headers['access-control-allow-origin'], ['https://a.com']);
    expect(res.headers.value('access-control-allow-methods'), contains('GET'));
    await res.drain<void>();
  });

  test('gives a preflight from a disallowed origin no allow-origin', () async {
    final res = await send(
      listed,
      'OPTIONS',
      '/ping',
      headers: {
        'Origin': 'https://evil.com',
        'Access-Control-Request-Method': 'GET',
      },
    );
    expect(res.headers.value('access-control-allow-origin'), isNull);
    await res.drain<void>();
  });

  test('lets a plain OPTIONS request reach its @Options route', () async {
    final res = await send(wildcard, 'OPTIONS', '/widgets');
    expect(res.statusCode, 200);
    expect(
      jsonDecode(await res.transform(utf8.decoder).join()),
      {'methods': 'GET, OPTIONS'},
    );
  });

  test('answers a plain OPTIONS without a route with 405', () async {
    final res = await send(wildcard, 'OPTIONS', '/ping');
    expect(res.statusCode, 405);
    expect(res.headers.value('allow'), 'GET');
    await res.drain<void>();
  });
}
