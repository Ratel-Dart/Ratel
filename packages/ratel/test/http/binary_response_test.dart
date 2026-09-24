import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/binary_response_controller_definition.dart';

void main() {
  final server = RatelServer(
    port: 0,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(
        controllers: [BinaryResponseControllerDefinition.value],
      ),
    ),
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

  test('Response.bytes writes a raw binary body', () async {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/bytes'));
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), 'hello');
  });
}
