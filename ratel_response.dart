import 'dart:convert';
import 'dart:io';

class Response {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  Response({
    required this.statusCode,
    this.data,
    this.headers = const {
      HttpHeaders.contentTypeHeader: 'application/json',
    },
  });

  static Response from(dynamic value) {
    if (value is Response) return value;

    return Response(
      statusCode: HttpStatus.ok,
      data: value,
    );
  }

  String toJson() {
    if (data is String) return data;
    return jsonEncode(data);
  }

  void send(HttpResponse response) {
    response.statusCode = statusCode;
    headers.forEach((key, value) => response.headers.set(key, value));
    response.write(toJson());
    response.close();
  }
}
