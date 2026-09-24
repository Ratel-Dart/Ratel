import '../exceptions/too_many_requests_exception.dart';
import 'middleware.dart';
import 'rate_window.dart';

abstract final class RateLimitMiddleware {
  static Middleware create({
    int maxRequests = 100,
    Duration window = const Duration(minutes: 1),
  }) {
    final windows = <String, RateWindow>{};
    return (ctx, next) async {
      final ip = ctx.request.connectionInfo?.remoteAddress.address ?? 'unknown';
      final now = DateTime.now();

      if (windows.length > 10000) {
        windows.removeWhere((_, w) => now.isAfter(w.resetAt));
      }

      final current = windows[ip];
      if (current == null || now.isAfter(current.resetAt)) {
        windows[ip] = RateWindow(now.add(window), 1);
      } else {
        current.count++;
        if (current.count > maxRequests) {
          final retryAfter = current.resetAt.difference(now).inSeconds;
          throw TooManyRequestsException(
            retryAfterSeconds: retryAfter < 1 ? 1 : retryAfter,
          );
        }
      }
      return next();
    };
  }
}
