import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

part 'binary_response_test.g.dart';

class _BinController extends RatelHandler {
  @override
  void registerRoutes() => _$_BinControllerRoutes(this);

  @Get('/bytes')
  Future<Response> bytes() async =>
      Response.bytes(statusCode: 200, data: utf8.encode('hello'));
}

void main() {
  final server = RatelServer(port: 0, handlers: [_BinController()]);
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
