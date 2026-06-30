import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _DataController extends RatelHandler {
  @Get('/data')
  Future<Response> data() async => Response.json(
        statusCode: 200,
        data: {'items': List.generate(200, (i) => 'item-$i')},
      );
}

void main() {
  final server = RatelServer(port: 0, handlers: [_DataController]);
  final client = HttpClient()..autoUncompress = false;
  late int port;

  setUpAll(() async {
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
  });

  test('gzip-compresses responses when the client accepts it', () async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/data'));
    req.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
    final res = await req.close();
    expect(res.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
    await res.drain<void>();
  });
}
