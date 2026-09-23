import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'cross_library_body_model.dart';
import 'cross_library_body_model.ratel.dart' as model;
import 'cross_library_body_test.ratel.dart';

class InvoiceController extends RatelHandler {
  @Post('/invoices')
  Future<Response> create(@Body() Invoice invoice) async => Response.json(
        statusCode: 201,
        data: {'reference': invoice.reference, 'amount': invoice.amount},
      );
}

void main() {
  final server = RatelServer(port: 0);
  final client = HttpClient();
  late int port;

  setUpAll(() async {
    RatelHandler.reset();
    RatelJson.reset();
    model.$registerRatel();
    $registerRatel();
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
  });

  test('deserializes a @Body model declared in another library', () async {
    final req =
        await client.postUrl(Uri.parse('http://127.0.0.1:$port/invoices'));
    req.headers.contentType = ContentType.json;
    req.write('{"reference":"INV-1","amount":42}');
    final res = await req.close();
    expect(res.statusCode, 201);
    expect(
      await res.transform(utf8.decoder).join(),
      '{"reference":"INV-1","amount":42}',
    );
  });
}
