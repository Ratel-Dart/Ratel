import 'package:postgres/postgres.dart';

/// Parses the `DB_SSL_MODE` environment value into an [SslMode].
///
/// Accepts `disable`, `verify_full` and `require`; a missing value means
/// [SslMode.require].
SslMode parseSslMode(String? value) {
  switch (value) {
    case 'disable':
      return SslMode.disable;
    case 'verify_full':
      return SslMode.verifyFull;
    case null:
    case 'require':
      return SslMode.require;
    default:
      throw StateError('Invalid DB_SSL_MODE: $value');
  }
}
