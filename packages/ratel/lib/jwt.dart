import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'core/logger.dart';

/// Validates `Authorization: Bearer <token>` headers against a shared [secret].
///
/// Returns the decoded claims on success, or `null` when the token is missing,
/// malformed, expired, or fails [issuer]/[audience] checks. By default a token
/// **must** carry an `exp` claim ([requireExpiry]); the underlying library only
/// checks expiry when the claim is present, so a token without one would
/// otherwise never expire.
class JwtAuthMiddleware {
  /// The shared HMAC secret used to verify tokens.
  final String secret;

  /// When set, the token's `iss` claim must equal this value.
  final String? issuer;

  /// When set, the token's `aud` claim must contain this value.
  final String? audience;

  /// When true (the default), tokens without an `exp` claim are rejected.
  final bool requireExpiry;

  /// Creates a middleware that verifies HS-signed tokens with [secret].
  JwtAuthMiddleware(
    this.secret, {
    this.issuer,
    this.audience,
    this.requireExpiry = true,
  });

  /// Extracts the bearer token from [request] and validates it. Returns the
  /// claims, or `null` when the header is absent or not a bearer token.
  Future<Map<String, dynamic>?> validate(HttpRequest request) async {
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    return validateToken(authHeader.substring('Bearer '.length));
  }

  /// Validates a raw JWT [token], returning its claims or `null` when invalid.
  ///
  /// Distinct failure modes are logged separately so attacks can be observed,
  /// rather than collapsing every case into an indistinguishable `null`.
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
