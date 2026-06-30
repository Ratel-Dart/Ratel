import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _CookieController extends RatelHandler {
  @Get('/set')
  Future<Response> set() async =>
      Response.json(statusCode: 200, data: {'ok': true})
          .withCookie(Cookie('session', 'abc'));
}

void main() {
  final server = RatelServer(port: 0, handlers: [_CookieController]);
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

  test('withCookie emits a Set-Cookie header', () async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/set'));
    final res = await req.close();
    final session = res.cookies.firstWhere((c) => c.name == 'session');
    expect(session.value, 'abc');
    await res.drain<void>();
  });
}
