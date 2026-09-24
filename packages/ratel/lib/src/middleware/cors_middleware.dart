import 'dart:io';

import '../http/request_context.dart';
import '../http/response.dart';
import 'middleware.dart';

abstract final class CorsMiddleware {
  static const _anyOrigin = '*';

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
    final wildcard = allowedOrigins.contains(_anyOrigin);
    final grants = <String, String>{
      'Access-Control-Allow-Methods': allowedMethods.join(', '),
      'Access-Control-Allow-Headers': allowedHeaders.join(', '),
      if (allowCredentials) 'Access-Control-Allow-Credentials': 'true',
    };
    return (ctx, next) async {
      final origin = ctx.request.headers.value('origin');
      final allowed = wildcard
          ? _anyOrigin
          : (allowedOrigins.contains(origin) ? origin : null);
      final headers = <String, String>{
        if (allowed != null) ...{
          'Access-Control-Allow-Origin': allowed,
          ...grants,
        },
      };
      final response = _isPreflight(ctx, origin)
          ? Response(statusCode: HttpStatus.noContent, headers: headers)
          : (await next()).withHeaders(headers);
      return wildcard ? response : _varyOnOrigin(response);
    };
  }

  static bool _isPreflight(RequestContext ctx, String? origin) {
    final requested =
        ctx.request.headers.value(HttpHeaders.accessControlRequestMethodHeader);
    return ctx.method == 'OPTIONS' && origin != null && requested != null;
  }

  static Response _varyOnOrigin(Response response) {
    final key = response.headers.keys.firstWhere(
      (name) => name.toLowerCase() == HttpHeaders.varyHeader,
      orElse: () => 'Vary',
    );
    final current = response.headers[key];
    return response.withHeaders({
      key: current == null ? 'Origin' : '$current, Origin',
    });
  }
}
