import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

Route _name(String name) => Route(
      path: '/who',
      method: 'GET',
      handler: (_) async => Response.json(data: {'server': name}),
    );

Route get _limit => Route(
      path: '/limit',
      method: 'GET',
      handler: (ctx) async => Response.json(
        data: {
          'limit': ctx.limits.maxRequestBodyBytes,
          'drain': ctx.limits.maxBodyDrainBytes,
        },
      ),
    );

void main() {
  final alpha = RatelRegistry()
    ..register(_name('alpha'))
    ..register(_limit);
  final beta = RatelRegistry()
    ..register(_name('beta'))
    ..register(_limit);

  final alphaServer = RatelServer(
    port: 0,
    registry: alpha,
    maxRequestBodyBytes: 1024,
    maxBodyDrainBytes: 2048,
  );
  final betaServer = RatelServer(
    port: 0,
    registry: beta,
    maxRequestBodyBytes: 16,
    maxBodyDrainBytes: 32,
  );
  final client = HttpClient();

  setUpAll(() async {
    await alphaServer.startServer();
    await betaServer.startServer();
  });

  tearDownAll(() async {
    client.close(force: true);
    await alphaServer.stop(force: true);
    await betaServer.stop(force: true);
  });

  Future<HttpClientResponse> send(
    RatelServer server,
    String method,
    String path, {
    String? body,
  }) async {
    final req = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.boundPort}$path'),
    );
    if (body != null) req.write(body);
    return req.close();
  }

  test('each server serves the routes of its own registry', () async {
    final fromAlpha = await send(alphaServer, 'GET', '/who');
    final fromBeta = await send(betaServer, 'GET', '/who');

    expect(jsonDecode(await fromAlpha.transform(utf8.decoder).join()),
        {'server': 'alpha'});
    expect(jsonDecode(await fromBeta.transform(utf8.decoder).join()),
        {'server': 'beta'});
  });

  test('each handler reads the body limits of the server it ran on', () async {
    final fromAlpha = await send(alphaServer, 'GET', '/limit');
    final fromBeta = await send(betaServer, 'GET', '/limit');

    expect(jsonDecode(await fromAlpha.transform(utf8.decoder).join()),
        {'limit': 1024, 'drain': 2048});
    expect(jsonDecode(await fromBeta.transform(utf8.decoder).join()),
        {'limit': 16, 'drain': 32});
  });

  test('an isolated injector keeps its registrations to itself', () {
    final scoped = Injector.scoped()..put<Duration>(() => Duration.zero);

    expect(scoped.get<Duration>(), Duration.zero);
    expect(() => Injector().get<Duration>(), throwsA(isA<Exception>()));
  });
}
