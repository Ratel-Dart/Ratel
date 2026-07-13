import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

part 'integration_test.g.dart';

class _ApiController extends RatelHandler {
  @override
  void registerRoutes() => _$_ApiControllerRoutes(this);

  @Get('/public')
  Future<Response> public() async =>
      Response.json(statusCode: 200, data: {'ok': true});

  @Protected()
  @Get('/secure')
  Future<Response> secure() async =>
      Response.json(statusCode: 200, data: {'ok': true});

  @Protected(roles: ['admin'])
  @Get('/admin')
  Future<Response> admin() async =>
      Response.json(statusCode: 200, data: {'ok': true});
}

void main() {
  final server = RatelServer(
    port: 0,
    handlers: [_ApiController()],
    jwtKey: 'secret',
    middlewares: [corsMiddleware(), securityHeadersMiddleware()],
  );
  final client = HttpClient();
  late int port;

  String tokenFor({List<String>? roles}) {
    final payload = <String, dynamic>{'sub': 'u1'};
    if (roles != null) payload['roles'] = roles;
    return JWT(payload)
        .sign(SecretKey('secret'), expiresIn: Duration(hours: 1));
  }

  Future<HttpClientResponse> send(
    String method,
    String path, {
    String? token,
  }) async {
    final req =
        await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
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

  test('serves a public route', () async {
    final res = await send('GET', '/public');
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), contains('"ok":true'));
  });

  test('unknown route returns 404', () async {
    final res = await send('GET', '/nope');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('protected route without a token returns 401', () async {
    final res = await send('GET', '/secure');
    expect(res.statusCode, 401);
    await res.drain<void>();
  });

  test('protected route with a valid token returns 200', () async {
    final res = await send('GET', '/secure', token: tokenFor());
    expect(res.statusCode, 200);
    await res.drain<void>();
  });

  test('role-restricted route returns 403 without the role', () async {
    final res = await send('GET', '/admin', token: tokenFor());
    expect(res.statusCode, 403);
    await res.drain<void>();
  });

  test('role-restricted route returns 200 with the role', () async {
    final res = await send('GET', '/admin', token: tokenFor(roles: ['admin']));
    expect(res.statusCode, 200);
    await res.drain<void>();
  });

  test('CORS preflight is answered with 204 and headers', () async {
    final res = await send('OPTIONS', '/public');
    expect(res.statusCode, 204);
    expect(res.headers.value('access-control-allow-origin'), isNotNull);
    await res.drain<void>();
  });

  test('responses carry security headers', () async {
    final res = await send('GET', '/public');
    expect(res.headers.value('x-content-type-options'), 'nosniff');
    await res.drain<void>();
  });
}
