import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import 'multipart_test.ratel.dart';

class UploadController extends RatelHandler {
  @Post('/upload')
  Future<Response> upload(MultipartData data) async {
    final avatar = data.file('avatar');
    return Response.json(data: {
      'title': data.fields['title'],
      'filename': avatar?.filename,
      'contentType': avatar?.contentType,
      'content': avatar == null ? null : utf8.decode(avatar.bytes),
      'attachments': data.filesFor('attachment').length,
    });
  }
}

void main() {
  final server = RatelServer(port: 0, maxRequestBodyBytes: 512);
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
}
