import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtAuthMiddleware {
  final String secret;

  JwtAuthMiddleware(this.secret);

  Future<Map<String, dynamic>?> validate(HttpRequest request) async {
    final authHeader = request.headers.value(HttpHeaders.authorizationHeader);
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    final token = authHeader.substring('Bearer '.length);
    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
