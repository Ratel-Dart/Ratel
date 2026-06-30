import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

@Json()
class _PatchBody {
  String name = '';
}

@Controller('/api')
class _UsersController extends RatelHandler {
  @Get('/users/:id')
  Future<Response> getUser(@PathParam('id') int id) async =>
      Response.json(statusCode: 200, data: {'id': id});

  @Patch('/users/:id')
  Future<Response> patchUser(
    @PathParam('id') int id,
    @Body() _PatchBody body,
  ) async =>
      Response.json(statusCode: 200, data: {'id': id, 'name': body.name});

  @Post('/users')
  Future<Response> create() async =>
      Response.json(statusCode: 201, data: {'created': true});
}

void main() {
  final server = RatelServer(port: 0, handlers: [_UsersController]);
  final client = HttpClient();
  late int port;

  Future<HttpClientResponse> send(
    String method,
    String path, {
    String? body,
  }) async {
    final req =
        await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(body);
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

  test('binds a path parameter and the controller prefix', () async {
    final res = await send('GET', '/api/users/42');
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), '{"id":42}');
  });

  test('coerces a path parameter and 400s on a bad value', () async {
    final res = await send('GET', '/api/users/abc');
    expect(res.statusCode, 400);
    await res.drain<void>();
  });

  test('routes a PATCH with both a path param and a body', () async {
    final res = await send('PATCH', '/api/users/7', body: '{"name":"ada"}');
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), '{"id":7,"name":"ada"}');
  });

  test('returns 405 with an Allow header on method mismatch', () async {
    final res = await send('DELETE', '/api/users/7');
    expect(res.statusCode, 405);
    final allow = res.headers.value('allow')!;
    expect(allow.contains('GET'), isTrue);
    expect(allow.contains('PATCH'), isTrue);
    await res.drain<void>();
  });

  test('returns 404 when the path is unknown', () async {
    final res = await send('GET', '/api/nope');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });

  test('does not match without the controller prefix', () async {
    final res = await send('GET', '/users/42');
    expect(res.statusCode, 404);
    await res.drain<void>();
  });
}
