import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

@Json()
class _Form {
  String name = '';
  String city = '';
}

class _FormController extends RatelHandler {
  @Post('/submit')
  Future<Response> submit(@Body() _Form form) async => Response.json(
        statusCode: 200,
        data: {'name': form.name, 'city': form.city},
      );

  @Get('/old')
  Future<Response> old() async => Response.redirect('/new', statusCode: 301);
}

void main() {
  final server = RatelServer(port: 0, handlers: [_FormController]);
  final client = HttpClient();
  late int port;

  Future<HttpClientResponse> send(
    String method,
    String path, {
    String? body,
    String? contentType,
    bool followRedirects = true,
  }) async {
    final req =
        await client.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
    req.followRedirects = followRedirects;
    if (body != null) {
      if (contentType != null) {
        req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      req.write(body);
    }
    return req.close();
  }

  setUpAll(() async {
    await server.startServer();
    port = server.boundPort!;
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.stop(force: true);
  });

  test('parses an application/x-www-form-urlencoded body', () async {
    final res = await send(
      'POST',
      '/submit',
      body: 'name=ada&city=rio',
      contentType: 'application/x-www-form-urlencoded',
    );
    expect(res.statusCode, 200);
    expect(
      await res.transform(utf8.decoder).join(),
      '{"name":"ada","city":"rio"}',
    );
  });

  test('still parses a JSON body', () async {
    final res = await send(
      'POST',
      '/submit',
      body: '{"name":"ada","city":"rio"}',
      contentType: 'application/json',
    );
    expect(res.statusCode, 200);
    expect(
      await res.transform(utf8.decoder).join(),
      '{"name":"ada","city":"rio"}',
    );
  });

  test('Response.redirect sets the status and Location header', () async {
    final res = await send('GET', '/old', followRedirects: false);
    expect(res.statusCode, 301);
    expect(res.headers.value('location'), '/new');
    await res.drain<void>();
  });
}
