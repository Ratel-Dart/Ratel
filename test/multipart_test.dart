import 'dart:convert';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _UploadController extends RatelHandler {
  @Post('/upload')
  Future<Response> upload(MultipartData data) async {
    final file = data.file('avatar');
    return Response.json(statusCode: 200, data: {
      'title': data.fields['title'],
      'filename': file?.filename,
      'content': file == null ? null : utf8.decode(file.bytes),
    });
  }
}

void main() {
  final server = RatelServer(port: 0, handlers: [_UploadController]);
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

  test('parses multipart/form-data fields and files', () async {
    const boundary = 'X-RATEL-BOUNDARY';
    final body = '--$boundary\r\n'
        'content-disposition: form-data; name="title"\r\n\r\n'
        'hello\r\n'
        '--$boundary\r\n'
        'content-disposition: form-data; name="avatar"; filename="a.txt"\r\n'
        'content-type: text/plain\r\n\r\n'
        'file-content\r\n'
        '--$boundary--\r\n';

    final req =
        await client.postUrl(Uri.parse('http://127.0.0.1:$port/upload'));
    req.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );
    req.write(body);
    final res = await req.close();

    expect(res.statusCode, 200);
    final json = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
    expect(json['title'], 'hello');
    expect(json['filename'], 'a.txt');
    expect(json['content'], 'file-content');
  });
}
