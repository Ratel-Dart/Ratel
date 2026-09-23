import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'cookie_response_test.ratel.dart';

class CookieController extends RatelHandler {
  @Get('/sign-in')
  Future<Response> signIn() async =>
      Response.json(data: {'ok': true}).withCookie(
        Cookie('session', 'abc')
          ..httpOnly = true
          ..path = '/',
      );
}

void main() {
  final server = RatelServer(port: 0);
  final client = HttpClient();
  late int port;

  setUpAll(() async {
    RatelHandler.reset();
    $registerRatel();
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
  });

  test('withCookie emits a Set-Cookie header', () async {
    final req =
        await client.getUrl(Uri.parse('http://127.0.0.1:$port/sign-in'));
    final res = await req.close();
    final session = res.cookies.firstWhere((c) => c.name == 'session');
    expect(session.value, 'abc');
    expect(session.httpOnly, isTrue);
    await res.drain<void>();
  });

  test('withHeaders keeps the cookies already attached', () {
    final response = Response.json(data: {'ok': true})
        .withCookie(Cookie('session', 'abc'))
        .withHeaders({'X-Trace': '1'});

    expect(response.headers['X-Trace'], '1');
    expect(response.cookies.single.name, 'session');
  });
}
