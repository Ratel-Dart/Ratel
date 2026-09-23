import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'body_limit_test.ratel.dart';

@Json()
class Note {
  String text = '';
}

class NoteController extends RatelHandler {
  @Get('/ping')
  Future<Response> ping() async => Response.json(data: {'ok': true});

  @Post('/notes')
  Future<Response> create(@Body() Note note) async =>
      Response.json(data: {'length': note.text.length});
}

void main() {
  final server = RatelServer(port: 0, maxRequestBodyBytes: 256);
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

  Future<HttpClientResponse> post(String path, String body) async {
    final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port$path'));
    req.headers.contentType = ContentType.json;
    req.write(body);
    return req.close();
  }

  Future<void> ping() async {
    final res =
        await (await client.getUrl(Uri.parse('http://127.0.0.1:$port/ping')))
            .close();
    expect(res.statusCode, 200);
    await res.drain<void>();
  }

  test('answers 413 on a connection that already served a request', () async {
    // Regression: the oversized body left the request stream unread, so
    // dart:io reset the socket before the client could read the response.
    await ping();

    final res = await post('/notes', jsonEncode({'text': 'x' * 4000}));
    final body = jsonDecode(await utf8.decodeStream(res));

    expect(res.statusCode, 413);
    expect(body['error'], 'Request body exceeds the limit of 256 bytes');
  });

  test('keeps serving the same connection after a 413', () async {
    await ping();
    final rejected = await post('/notes', jsonEncode({'text': 'x' * 4000}));
    expect(rejected.statusCode, 413);
    await rejected.drain<void>();

    final accepted = await post('/notes', jsonEncode({'text': 'ok'}));
    expect(accepted.statusCode, 200);
    expect(jsonDecode(await utf8.decodeStream(accepted)), {'length': 2});
  });

  test('answers 404 for a POST that carries a body', () async {
    await ping();
    final res = await post('/missing', jsonEncode({'text': 'x' * 4000}));
    final body = jsonDecode(await utf8.decodeStream(res));

    expect(res.statusCode, 404);
    expect(body['error'], 'Not Found');
  });

  test('accepts a body that fits the limit', () async {
    final res = await post('/notes', jsonEncode({'text': 'hello'}));
    expect(res.statusCode, 200);
    expect(jsonDecode(await utf8.decodeStream(res)), {'length': 5});
  });
}
