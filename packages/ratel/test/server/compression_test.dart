import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/compression_controller_definition.dart';

void main() {
  final server = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(controllers: [CompressionControllerDefinition.value]),
    ),
  );
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
