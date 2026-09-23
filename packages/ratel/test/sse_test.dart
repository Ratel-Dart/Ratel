import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'sse_test.ratel.dart';

final ticks = StreamController<String>();
final held = StreamController<String>();

class EventsController extends RatelHandler {
  @Get('/events')
  Future<Response> events() async =>
      Response.sse(Stream.fromIterable(['a', 'b', 'c']));

  @Get('/ticks')
  Future<Response> live() async => Response.sse(ticks.stream);

  @Get('/held')
  Future<Response> hold() async => Response.sse(held.stream);
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

  Future<HttpClientResponse> open(String path, {bool gzip = false}) async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    if (gzip) {
      req.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
    }
    return req.close();
  }

  test('streams events as text/event-stream', () async {
    final res = await open('/events');
    expect(res.headers.value('content-type'), 'text/event-stream');
    expect(res.headers.value('cache-control'), 'no-cache');
    expect(
      await res.transform(utf8.decoder).join(),
      ':\n\ndata: a\n\ndata: b\n\ndata: c\n\n',
    );
  });

  test('is not held back by a gzip buffer', () async {
    final res = await open('/events', gzip: true);
    expect(res.headers.value('content-encoding'), 'identity');
    expect(
      await res.transform(utf8.decoder).join(),
      ':\n\ndata: a\n\ndata: b\n\ndata: c\n\n',
    );
  });

  test('answers the headers before the first event arrives', () async {
    final res = await open('/ticks');
    expect(res.statusCode, 200);

    final received = <String>[];
    final done = Completer<void>();
    res.transform(utf8.decoder).listen(received.add, onDone: done.complete);

    ticks.add('first');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received.join(), ':\n\ndata: first\n\n');

    await ticks.close();
    await done.future;
  });

  test('keeps serving other routes while a stream is open', () async {
    final stream = await open('/held');
    final drained = stream.drain<void>();

    final res = await open('/events').timeout(const Duration(seconds: 5));
    expect(res.statusCode, 200);
    await res.drain<void>();

    await held.close();
    await drained;
  });

  test('answers HEAD on an event stream without streaming it', () async {
    final req = await client.openUrl(
        'HEAD', Uri.parse('http://127.0.0.1:$port/events'));
    final res = await req.close().timeout(const Duration(seconds: 5));

    expect(res.statusCode, 200);
    expect(res.headers.value('content-type'), 'text/event-stream');
    expect(await res.transform(utf8.decoder).join(), isEmpty);
  });
}
