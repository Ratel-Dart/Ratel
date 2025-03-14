import 'dart:convert';
import 'dart:io';

class ApiResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, List<String>> headers;
  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
  ApiResponse(
      {required this.statusCode, required this.data, required this.headers});
}

class Request {
  final Uri baseUri;
  final Map<String, String> defaultHeaders;
  Request(String baseUrl, {this.defaultHeaders = const {}})
      : baseUri = Uri.parse(baseUrl);
  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
          queryParameters:
              queryParameters.map((k, v) => MapEntry(k, v.toString())));
    }
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(uri);
    _applyHeaders(request, headers);
    final response = await request.close();
    return _processResponse(response);
  }

  Future<ApiResponse> post(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
          queryParameters:
              queryParameters.map((k, v) => MapEntry(k, v.toString())));
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

  Future<ApiResponse> put(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
          queryParameters:
              queryParameters.map((k, v) => MapEntry(k, v.toString())));
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

  Future<ApiResponse> delete(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) async {
    Uri uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
          queryParameters:
              queryParameters.map((k, v) => MapEntry(k, v.toString())));
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
    defaultHeaders.forEach((key, value) => request.headers.set(key, value));
    if (headers != null) {
      headers.forEach((key, value) => request.headers.set(key, value));
    }
  }

  Future<ApiResponse> _processResponse(HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();
    dynamic data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      data = body;
    }
    final headerMap = <String, List<String>>{};
    response.headers.forEach((name, values) {
      headerMap[name] = values;
    });
    return ApiResponse(
        statusCode: response.statusCode, data: data, headers: headerMap);
  }
}
