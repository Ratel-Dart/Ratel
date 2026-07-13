import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

part 'param_injection_test.g.dart';

class _CtxController extends RatelHandler {
  @override
  void registerRoutes() => _$_CtxControllerRoutes(this);

  @Get('/header')
  Future<Response> header(@Header('X-User') String? user) async =>
      Response.json(statusCode: 200, data: {'user': user});

  @Get('/cookie')
  Future<Response> cookie(@CookieParam('session') String? session) async =>
      Response.json(statusCode: 200, data: {'session': session});
}

void main() {
  final server = RatelServer(port: 0, handlers: [_CtxController()]);
  final client = HttpClient();
  late int port;

  Future<HttpClientResponse> get(String path,
      {void Function(HttpClientRequest)? prepare}) async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    prepare?.call(req);
    return req.close();
  }

  setUpAll(() async {
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
  });

  test('binds a request header with @Header', () async {
    final res =
        await get('/header', prepare: (r) => r.headers.set('X-User', 'ada'));
    expect(await res.transform(utf8.decoder).join(), '{"user":"ada"}');
  });

  test('@Header is null when the header is absent', () async {
    final res = await get('/header');
    expect(await res.transform(utf8.decoder).join(), '{"user":null}');
  });

  test('binds a request cookie with @CookieParam', () async {
    final res = await get('/cookie',
        prepare: (r) => r.cookies.add(Cookie('session', 'abc')));
    expect(await res.transform(utf8.decoder).join(), '{"session":"abc"}');
  });
}
