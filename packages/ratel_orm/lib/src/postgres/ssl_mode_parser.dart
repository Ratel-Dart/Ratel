import 'package:postgres/postgres.dart';

abstract final class SslModeParser {
  static SslMode parse(String? value) => switch (value) {
        'disable' => SslMode.disable,
        'verify_full' => SslMode.verifyFull,
        null || 'require' => SslMode.require,
        _ => throw StateError('Invalid DB_SSL_MODE: $value'),
      };
}
