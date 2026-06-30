import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

@Protected()
class _CtxHeadController extends RatelHandler {
  @Public()
  @Get('/ping')
  Future<Response> ping() async =>
      Response.json(statusCode: 200, data: {'ok': true});

  @Get('/me')
  Future<Response> me(RequestContext ctx) async =>
      Response.json(statusCode: 200, data: {'sub': ctx.claims?['sub']});
}

void main() {
  final server = RatelServer(
    port: 0,
    handlers: [_CtxHeadController],
    jwtKey: 'secret',
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

  test('injects RequestContext and exposes JWT claims to the handler',
      () async {
    final token = JWT({'sub': 'u1'})
        .sign(SecretKey('secret'), expiresIn: Duration(hours: 1));
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/me'));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), '{"sub":"u1"}');
  });

  test('auto-handles HEAD using the GET route, with no body', () async {
    final req =
        await client.openUrl('HEAD', Uri.parse('http://127.0.0.1:$port/ping'));
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), isEmpty);
  });
}
