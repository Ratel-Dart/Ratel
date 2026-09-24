import '../auth/jwt_validator.dart';
import '../exceptions/forbidden_exception.dart';
import '../exceptions/unauthorized_exception.dart';
import 'middleware.dart';

abstract final class JwtAuthMiddleware {
  static Middleware create(
    JwtValidator validator, {
    String rolesClaim = 'roles',
  }) {
    return (ctx, next) async {
      final route = ctx.route;
      if (route != null && route.isProtected) {
        final claims = await validator.validate(ctx.request);
        if (claims == null) {
          throw const UnauthorizedException('Invalid or missing token');
        }
        ctx.claims = claims;
        if (route.requiredRoles.isNotEmpty) {
          final held = _rolesFrom(claims[rolesClaim]);
          final allowed = route.requiredRoles.any(held.contains);
          if (!allowed) {
            throw const ForbiddenException('Insufficient role');
          }
        }
      }
      return next();
    };
  }

  static Set<String> _rolesFrom(dynamic value) {
    if (value is String) return {value};
    if (value is Iterable) return value.map((e) => e.toString()).toSet();
    return const {};
  }
}
