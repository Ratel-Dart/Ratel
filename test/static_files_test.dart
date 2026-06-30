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
      middlewares: [
        staticFiles(directory: publicDir.path, urlPrefix: '/static'),
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

  Future<HttpClientResponse> get(String path) async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    return req.close();
  }

  test('serves a file with the right content type', () async {
    final res = await get('/static/index.html');
    expect(res.statusCode, 200);
    expect(res.headers.value('content-type'), contains('text/html'));
    expect(await res.transform(utf8.decoder).join(), '<h1>hi</h1>');
  });

  test('falls through to 404 for a missing file', () async {
    final res = await get('/static/missing.html');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('does not serve files outside the directory (traversal)', () async {
    final res = await get('/static/%2e%2e/secret.txt');
    expect(res.statusCode, isNot(200));
    await res.drain<void>();
  });
}
