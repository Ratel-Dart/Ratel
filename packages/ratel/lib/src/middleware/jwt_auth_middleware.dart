import '../auth/jwt_authorizer.dart';
import '../auth/jwt_validator.dart';
import 'middleware.dart';

abstract final class JwtAuthMiddleware {
  static Middleware create(
    JwtValidator validator, {
    String rolesClaim = 'roles',
  }) {
    return (ctx, next) async {
      final route = ctx.route;
      if (route != null && route.isProtected) {
        final claims = await JwtAuthorizer.claims(validator, ctx.request);
        ctx.claims = claims;
        JwtAuthorizer.requireRoles(
          claims,
          route.requiredRoles,
          rolesClaim: rolesClaim,
        );
      }
      return next();
    };
  }
}
