import 'middleware.dart';

abstract final class SecurityHeadersMiddleware {
  static Middleware create({
    bool hsts = false,
    String frameOptions = 'DENY',
    String? contentSecurityPolicy,
  }) {
    final headers = <String, String>{
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': frameOptions,
      'Referrer-Policy': 'no-referrer',
      if (hsts)
        'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      if (contentSecurityPolicy != null)
        'Content-Security-Policy': contentSecurityPolicy,
    };
    return (ctx, next) async {
      final response = await next();
      return response.withHeaders(headers);
    };
  }
}
