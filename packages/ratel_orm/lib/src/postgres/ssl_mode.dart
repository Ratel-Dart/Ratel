import 'package:postgres/postgres.dart';

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
