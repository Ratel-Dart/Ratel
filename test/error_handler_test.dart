import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _BoomController extends RatelHandler {
  @Get('/boom')
  Future<Response> boom() async => throw StateError('kaboom');
}

void main() {
  final server = RatelServer(
    port: 0,
    handlers: [_BoomController],
    onError: (error, stack, ctx) =>
        Response(statusCode: 503, data: {'handled': true, 'path': ctx.path}),
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

  test('onError maps an unexpected error to a custom response', () async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/boom'));
    final res = await req.close();
    expect(res.statusCode, 503);
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    expect(body['handled'], true);
    expect(body['path'], '/boom');
  });
}
