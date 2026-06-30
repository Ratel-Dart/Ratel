import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _PingController extends RatelHandler {
  @Get('/ping')
  Future<Response> ping() async =>
      Response.json(statusCode: 200, data: {'ok': true});
}

var _entryRuns = 0;
void _countEntry(List<String> args) {
  _entryRuns++;
}

void main() {
  test('a shared server binds and serves requests', () async {
    final server =
        RatelServer(port: 0, handlers: [_PingController], shared: true);
    await server.startServer();
    final client = HttpClient();
    final req = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/ping'));
    final res = await req.close();
    expect(res.statusCode, 200);
    await res.drain<void>();
    client.close(force: true);
    await server.stop(force: true);
  });

  test('runCluster runs the entry point on the calling isolate', () async {
    _entryRuns = 0;
    await runCluster(_countEntry, isolates: 1);
    expect(_entryRuns, 1);
  });
}
