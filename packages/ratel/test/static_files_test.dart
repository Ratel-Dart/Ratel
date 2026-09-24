import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempRoot;
  late Directory publicDir;
  late RatelServer server;
  final client = HttpClient();
  late int port;

  setUpAll(() async {
    tempRoot = await Directory.systemTemp.createTemp('ratel_static_');
    publicDir = Directory('${tempRoot.path}/public');
    await publicDir.create();
    await File('${publicDir.path}/index.html').writeAsString('<h1>hi</h1>');
    await File('${tempRoot.path}/secret.txt').writeAsString('top secret');

    server = RatelServer(
      port: 0,
      registry: RatelRegistry(),
      middlewares: [
        StaticFilesMiddleware.create(
            directory: publicDir.path, urlPrefix: '/static'),
      ],
    );
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
    await tempRoot.delete(recursive: true);
  });

  Future<HttpClientResponse> send(String method, String path) async {
    final req =
        await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    return req.close();
  }

  test('serves a file with the right content type', () async {
    final res = await send('GET', '/static/index.html');
    expect(res.statusCode, 200);
    expect(res.headers.value('content-type'), 'text/html; charset=utf-8');
    expect(await res.transform(utf8.decoder).join(), '<h1>hi</h1>');
  });

  test('falls through to 404 for a missing file', () async {
    final res = await send('GET', '/static/missing.html');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('does not serve files outside the directory', () async {
    final res = await send('GET', '/static/%2e%2e/secret.txt');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('does not match a path that only shares the prefix', () async {
    final res = await send('GET', '/staticky/index.html');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('leaves methods other than GET to the router', () async {
    final res = await send('POST', '/static/index.html');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });
}
