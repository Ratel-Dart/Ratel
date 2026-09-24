import 'dart:io';

import '../http/response.dart';
import 'middleware.dart';

abstract final class CorsMiddleware {
  static Middleware create({
    List<String> allowedOrigins = const ['*'],
    List<String> allowedMethods = const [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'OPTIONS',
    ],
    List<String> allowedHeaders = const ['Content-Type', 'Authorization'],
    bool allowCredentials = false,
  }) {
    final headers = <String, String>{
      'Access-Control-Allow-Origin': allowedOrigins.join(', '),
      'Access-Control-Allow-Methods': allowedMethods.join(', '),
      'Access-Control-Allow-Headers': allowedHeaders.join(', '),
      if (allowCredentials) 'Access-Control-Allow-Credentials': 'true',
    };
    return (ctx, next) async {
      if (ctx.method == 'OPTIONS') {
        return Response(statusCode: HttpStatus.noContent, headers: headers);
      }
      final response = await next();
      return response.withHeaders(headers);
    };
  }
}
