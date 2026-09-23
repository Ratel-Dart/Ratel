import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'rate_limit_test.ratel.dart';

class PingController extends RatelHandler {
  @Get('/ping')
  Future<Response> ping() async => Response.json(data: {'ok': true});
}

void main() {
  final server = RatelServer(
    port: 0,
    middlewares: [
      rateLimitMiddleware(maxRequests: 2, window: Duration(minutes: 1)),
    ],
  );
  final client = HttpClient();
  late int port;

  Future<HttpClientResponse> ping() async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/ping'));
    return req.close();
  }

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

  test('allows up to the limit, then 429 with a Retry-After header', () async {
    for (var i = 0; i < 2; i++) {
      final res = await ping();
      expect(res.statusCode, 200);
      await res.drain<void>();
    }
    final limited = await ping();
    expect(limited.statusCode, 429);
    expect(limited.headers.value('retry-after'), isNotNull);
    await limited.drain<void>();
  });
}
