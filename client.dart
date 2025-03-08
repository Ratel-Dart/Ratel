import 'dart:convert';
import 'dart:io';

class RatelClient {
  final Uri baseUri;
  final Map<String, String> defaultHeaders;

  RatelClient(String baseUrl, {this.defaultHeaders = const {}})
      : baseUri = Uri.parse(baseUrl);

  Future<dynamic> get(String path,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
        queryParameters:
            queryParameters.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(uri);
    _applyHeaders(request, headers);
    final response = await request.close();
    return _processResponse(response);
  }

  Future<dynamic> post(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
        queryParameters:
            queryParameters.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    final httpClient = HttpClient();
    final request = await httpClient.postUrl(uri);
    _applyHeaders(request, headers);
    if (body != null) {
      if (body is String) {
        request.write(body);
      } else {
        request.write(jsonEncode(body));
      }
    }
    final response = await request.close();
    return _processResponse(response);
  }

  Future<dynamic> put(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
        queryParameters:
            queryParameters.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    final httpClient = HttpClient();
    final request = await httpClient.putUrl(uri);
    _applyHeaders(request, headers);
    if (body != null) {
      if (body is String) {
        request.write(body);
      } else {
        request.write(jsonEncode(body));
      }
    }
    final response = await request.close();
    return _processResponse(response);
  }

  Future<dynamic> delete(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
        queryParameters:
            queryParameters.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    final httpClient = HttpClient();
    final request = await httpClient.deleteUrl(uri);
    _applyHeaders(request, headers);
    if (body != null) {
      if (body is String) {
        request.write(body);
      } else {
        request.write(jsonEncode(body));
      }
    }
    final response = await request.close();
    return _processResponse(response);
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String>? headers) {
    defaultHeaders.forEach((key, value) {
      request.headers.set(key, value);
    });
    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
    }
  }

  Future<dynamic> _processResponse(HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(body);
      } catch (e) {
        return body;
      }
    } else {
      throw HttpException(
        'Erro na requisição: ${response.statusCode} - $body',
        uri: response.redirects.isNotEmpty
            ? response.redirects.last.location
            : null,
      );
    }
  }
}
