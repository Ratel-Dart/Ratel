import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/user_patch_codec.dart';
import '../support/fixtures/definitions/users_controller_definition.dart';

void main() {
  final server = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(
        controllers: [UsersControllerDefinition.value],
        jsonCodecs: [UserPatchCodec.definition],
      ),
    )
      ..register(Route(
        method: 'GET',
        path: '/people/:name',
        handler: (ctx) async => Response.json(
          data: {'name': ctx.pathParams['name']},
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ))
      ..register(Route(
        method: 'GET',
        path: '/people/me',
        handler: (ctx) async => Response.json(
          data: {'me': true},
          headers: const {'x-route': 'me'},
        ),
      ))
      ..register(Route(
        method: 'GET',
        path: '/menu/caf%C3%A9',
        handler: (ctx) async => Response.json(data: {'cafe': true}),
      )),
  );
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

  Future<Object?> json(HttpClientResponse res) async =>
      jsonDecode(await res.transform(utf8.decoder).join());

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

  test('prefers a static route declared after a parameter route', () async {
    final res = await send('GET', '/people/me');
    expect(res.statusCode, 200);
    expect(await json(res), {'me': true});
  });

  test('still routes other values to the parameter route', () async {
    final res = await send('GET', '/people/ada');
    expect(res.statusCode, 200);
    expect(await json(res), {'name': 'ada'});
  });

  test('percent-decodes path parameters', () async {
    final unicode = await send('GET', '/people/Jo%C3%A3o');
    expect(unicode.statusCode, 200);
    expect(await json(unicode), {'name': 'João'});
    final spaced = await send('GET', '/people/Ada%20Lovelace');
    expect(spaced.statusCode, 200);
    expect(await json(spaced), {'name': 'Ada Lovelace'});
  });

  test('matches a static route written with escapes', () async {
    final res = await send('GET', '/menu/caf%C3%A9');
    expect(res.statusCode, 200);
    expect(await json(res), {'cafe': true});
  });

  test('answers 400 for a malformed percent escape', () async {
    final res = await send('GET', '/people/%E0%A4%A');
    expect(res.statusCode, 400);
    await res.drain<void>();
  });

  test('answers HEAD from the most specific GET route', () async {
    final res = await send('HEAD', '/people/me');
    expect(res.statusCode, 200);
    expect(res.headers.value('x-route'), 'me');
    expect(await res.transform(utf8.decoder).join(), isEmpty);
  });

  test('keeps the Allow header for a specific path', () async {
    final res = await send('DELETE', '/people/me');
    expect(res.statusCode, 405);
    expect(res.headers.value('allow'), 'GET');
    await res.drain<void>();
  });
}
