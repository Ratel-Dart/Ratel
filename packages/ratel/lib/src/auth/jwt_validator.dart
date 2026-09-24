import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../logging/ratel_logger.dart';

class JwtAuthMiddleware {
  final String secret;

  final String? issuer;

  final String? audience;

  final bool requireExpiry;

  JwtAuthMiddleware(
    this.secret, {
    this.issuer,
    this.audience,
    this.requireExpiry = true,
  });

  Future<Map<String, dynamic>?> validate(HttpRequest request) async {
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    return validateToken(authHeader.substring('Bearer '.length));
  }

  Map<String, dynamic>? validateToken(String token) {
    try {
      final jwt = JWT.verify(
        token,
        SecretKey(secret),
        issuer: issuer,
        audience: audience == null ? null : Audience.one(audience!),
      );

      final payload = jwt.payload;
      if (payload is! Map<String, dynamic>) {
        ratelLogger.warning('JWT rejected: payload is not a JSON object');
        return null;
      }
      if (requireExpiry && !payload.containsKey('exp')) {
        ratelLogger.warning('JWT rejected: missing required "exp" claim');
        return null;
      }
      return payload;
    } on JWTExpiredException {
      ratelLogger.info('JWT rejected: expired');
      return null;
    } on JWTException catch (e) {
      ratelLogger.info('JWT rejected: ${e.message}');
      return null;
    }
  }
}
