import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel/runtime.dart';
import 'package:test/test.dart';

import '../support/fixtures/definitions/multipart_upload_controller_definition.dart';
import '../support/fixtures/definitions/ping_controller_definition.dart';

void main() {
  final server = RatelServer(
    port: 0,
    maxRequestBodyBytes: 512,
    registry: RatelRegistry.fromManifest(
      const RatelManifest(
        controllers: [
          MultipartUploadControllerDefinition.value,
          PingControllerDefinition.value,
        ],
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

  Future<HttpClientResponse> post(String body, {String? contentType}) async {
    final req =
        await client.postUrl(Uri.parse('http://127.0.0.1:$port/upload'));
    req.headers.set(
      HttpHeaders.contentTypeHeader,
      contentType ?? 'multipart/form-data; boundary=RATEL',
    );
    req.write(body);
    return req.close();
  }

  String part(String headers, String content) =>
      '--RATEL\r\n$headers\r\n\r\n$content\r\n';

  Future<void> ping() async {
    final res =
        await (await client.getUrl(Uri.parse('http://127.0.0.1:$port/ping')))
            .close();
    expect(res.statusCode, 200);
    await res.drain<void>();
  }

  String oversized() =>
      '${part('content-disposition: form-data; name="big"; filename="big.txt"', 'x' * (900 * 1024))}'
      '--RATEL--\r\n';

  test('parses fields and files', () async {
    final res = await post(
      '${part('content-disposition: form-data; name="title"', 'hello')}'
      '${part('content-disposition: form-data; filename="a.txt"; name="avatar"\r\ncontent-type: text/plain', 'file-content')}'
      '${part('content-disposition: form-data; name="attachment"; filename="b.txt"', 'one')}'
      '${part('content-disposition: form-data; name="attachment"; filename="c.txt"', 'two')}'
      '--RATEL--\r\n',
    );

    expect(res.statusCode, 200);
    expect(jsonDecode(await res.transform(utf8.decoder).join()), {
      'title': 'hello',
      'filename': 'a.txt',
      'contentType': 'text/plain',
      'content': 'file-content',
      'attachments': 2,
    });
  });

  test('rejects a body that is not multipart', () async {
    final res = await post('{}', contentType: 'application/json');
    expect(res.statusCode, 400);
    await res.drain<void>();
  });

  test('rejects a multipart body without a boundary', () async {
    final res = await post('', contentType: 'multipart/form-data');
    expect(res.statusCode, 400);
    await res.drain<void>();
  });

  test('enforces the request body limit across parts', () async {
    final res = await post(
      '${part('content-disposition: form-data; name="big"; filename="big.txt"', 'x' * 600)}'
      '--RATEL--\r\n',
    );
    expect(res.statusCode, 413);
    await res.drain<void>();
  });

  test('answers 413 to a multipart body well over the limit', () async {
    await ping();

    final res = await post(oversized());
    final body = jsonDecode(await utf8.decodeStream(res));

    expect(res.statusCode, 413);
    expect(body['error'], 'Multipart body exceeds the limit of 512 bytes');
  });

  test('keeps serving the same connection after a multipart 413', () async {
    await ping();
    final rejected = await post(oversized());
    expect(rejected.statusCode, 413);
    await rejected.drain<void>();

    final accepted = await post(
      '${part('content-disposition: form-data; name="title"', 'ok')}'
      '--RATEL--\r\n',
    );
    expect(accepted.statusCode, 200);
    expect(jsonDecode(await utf8.decodeStream(accepted))['title'], 'ok');
  });
}
