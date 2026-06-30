import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _SseController extends RatelHandler {
  @Get('/events')
  Future<Response> events() async =>
      Response.sse(Stream.fromIterable(['a', 'b', 'c']));
}

void main() {
  final server = RatelServer(port: 0, handlers: [_SseController]);
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

  test('streams server-sent events as text/event-stream', () async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/events'));
    final res = await req.close();
    expect(res.headers.value('content-type'), contains('text/event-stream'));
    expect(
      await res.transform(utf8.decoder).join(),
      'data: a\n\ndata: b\n\ndata: c\n\n',
    );
  });
}
