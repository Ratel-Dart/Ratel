import 'dart:convert';
import 'dart:io';

final class HttpProbe {
  HttpProbe(this.port);

  final int port;

  Future<(int, String)> send(
    String method,
    String path, {
    Map<String, String> headers = const {},
    List<Cookie> cookies = const [],
    List<int>? body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://localhost:$port$path'),
      );
      headers.forEach(request.headers.set);
      request.cookies.addAll(cookies);
      if (body != null) request.add(body);
      final response = await request.close();
      return (
        response.statusCode,
        await response.transform(utf8.decoder).join()
      );
    } finally {
      client.close(force: true);
    }
  }
}
