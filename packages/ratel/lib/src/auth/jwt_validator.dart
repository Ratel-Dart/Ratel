import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../logging/ratel_logger.dart';

class JwtValidator {
  final String secret;

  final String? issuer;

  final String? audience;

  final bool requireExpiry;

  JwtValidator(
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
        RatelLogger.instance
            .warning('JWT rejected: payload is not a JSON object');
        return null;
      }
      if (requireExpiry && !payload.containsKey('exp')) {
        RatelLogger.instance
            .warning('JWT rejected: missing required "exp" claim');
        return null;
      }
      return payload;
    } on JWTExpiredException {
      RatelLogger.instance.info('JWT rejected: expired');
      return null;
    } on JWTException catch (e) {
      RatelLogger.instance.info('JWT rejected: ${e.message}');
      return null;
    }
  }
}
