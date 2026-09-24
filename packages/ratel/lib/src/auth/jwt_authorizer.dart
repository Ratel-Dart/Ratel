import 'dart:io';

import '../exceptions/forbidden_exception.dart';
import '../exceptions/unauthorized_exception.dart';
import 'jwt_validator.dart';

abstract final class JwtAuthorizer {
  static Future<Map<String, dynamic>> claims(
    JwtValidator validator,
    HttpRequest request,
  ) async {
    final claims = await validator.validate(request);
    if (claims == null) {
      throw const UnauthorizedException('Invalid or missing token');
    }
    return claims;
  }

  static void requireRoles(
    Map<String, dynamic> claims,
    List<String> requiredRoles, {
    String rolesClaim = 'roles',
  }) {
    if (requiredRoles.isEmpty) return;
    final held = _rolesFrom(claims[rolesClaim]);
    if (!requiredRoles.any(held.contains)) {
      throw const ForbiddenException('Insufficient role');
    }
  }

  static Set<String> _rolesFrom(dynamic value) {
    if (value is String) return {value};
    if (value is Iterable) return value.map((e) => e.toString()).toSet();
    return const {};
  }
}
