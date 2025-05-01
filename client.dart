import 'dart:convert';
import 'dart:io';

import 'exceptions/exceptions.dart';

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

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    var uri = baseUri.resolve(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(
        queryParameters:
            queryParameters.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    return uri;
  }

  Future<HttpClientRequest> _openRequest(
      HttpClient client, String method, Uri uri) {
    switch (method) {
      case 'GET':
        return client.getUrl(uri);
      case 'POST':
        return client.postUrl(uri);
      case 'PUT':
        return client.putUrl(uri);
      case 'DELETE':
        return client.deleteUrl(uri);
      default:
        throw ArgumentError('Invalid HTTP method: $method');
    }
  }

  void _writeBody(HttpClientRequest request, dynamic body) {
    if (body == null) return;
    if (body is String) {
      request.write(body);
    } else {
      request.write(jsonEncode(body));
    }
  }

  Future<T> _handleExceptions<T>(
      Future<T> Function() fn, Uri uri, String method) async {
    try {
      return await fn();
    } on SocketException {
      throw HttpRequestException('Error connecting to server',
          uri: uri, method: method);
    } on HttpException {
      throw HttpRequestException('Error during HTTP request',
          uri: uri, method: method);
    } catch (e) {
      throw HttpRequestException(e.toString(), uri: uri, method: method);
    }
  }

  Future<ApiResponse> _sendRequest(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final client = HttpClient();
    final result = await _handleExceptions(() async {
      final req = await _openRequest(client, method, uri);
      _applyHeaders(req, headers);
      _writeBody(req, body);
      final resp = await req.close();
      return _processResponse(resp, uri, method);
    }, uri, method);
    client.close();
    return result;
  }

  Future<ApiResponse> get(String path,
      {Map<String, dynamic>? queryParameters, Map<String, String>? headers}) {
    return _sendRequest('GET', path,
        queryParameters: queryParameters, headers: headers);
  }

  Future<ApiResponse> post(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) {
    return _sendRequest('POST', path,
        body: body, queryParameters: queryParameters, headers: headers);
  }

  Future<ApiResponse> put(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) {
    return _sendRequest('PUT', path,
        body: body, queryParameters: queryParameters, headers: headers);
  }

  Future<ApiResponse> delete(String path,
      {dynamic body,
      Map<String, dynamic>? queryParameters,
      Map<String, String>? headers}) {
    return _sendRequest('DELETE', path,
        body: body, queryParameters: queryParameters, headers: headers);
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String>? headers) {
    defaultHeaders.forEach((k, v) => request.headers.set(k, v));
    headers?.forEach((k, v) => request.headers.set(k, v));
  }

  Future<ApiResponse> _processResponse(
      HttpClientResponse response, Uri uri, String method) async {
    final body = await response.transform(utf8.decoder).join();
    dynamic data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      throw JsonDecodingException('Error decoding JSON', body: body);
    }
    final headerMap = <String, List<String>>{};
    response.headers.forEach((name, values) => headerMap[name] = values);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpResponseException(
        'HTTP response error',
        statusCode: response.statusCode,
        uri: uri,
        method: method,
      );
    }
    return ApiResponse(
        statusCode: response.statusCode, data: data, headers: headerMap);
  }
}
