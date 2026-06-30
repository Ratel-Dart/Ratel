import 'dart:io';

import 'package:postgres/postgres.dart';

import 'repository.dart';

/// PostgreSQL connection configuration for the framework's repositories.
///
/// Constructing one configures [RatelRepository] so repositories can obtain
/// connections. TLS is required by default ([sslMode]); use [RatelDatabase.fromEnv]
/// to load credentials from the environment instead of hard-coding them.
class RatelDatabase {
  /// Database host name.
  final String host;

  /// Database port (as a string for backwards compatibility).
  final String port;

  /// Name of the database to connect to.
  final String databaseName;

  /// Authentication user name.
  final String username;

  /// Authentication password.
  final String password;

  /// TLS mode for the connection. Defaults to [SslMode.require] so traffic is
  /// encrypted; set to [SslMode.disable] only for trusted local development.
  final SslMode sslMode;

  /// Creates a database configuration and registers it with [RatelRepository].
  RatelDatabase({
    required this.host,
    this.port = '5432',
    required this.databaseName,
    required this.username,
    required this.password,
    this.sslMode = SslMode.require,
  }) {
    RatelRepository.configure(this);
  }

  /// Builds the configuration from environment variables, keeping secrets out
  /// of source code: `DB_HOST`, `DB_PORT` (default `5432`), `DB_NAME`,
  /// `DB_USER`, `DB_PASSWORD`, and `DB_SSL_MODE` (`require` | `verify_full` |
  /// `disable`, default `require`).
  factory RatelDatabase.fromEnv() {
    final env = Platform.environment;

    String required(String key) {
      final value = env[key];
      if (value == null || value.isEmpty) {
        throw StateError('Missing required environment variable: $key');
      }
      return value;
    }

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

    return RatelDatabase(
      host: required('DB_HOST'),
      port: env['DB_PORT'] ?? '5432',
      databaseName: required('DB_NAME'),
      username: required('DB_USER'),
      password: required('DB_PASSWORD'),
      sslMode: parseSslMode(env['DB_SSL_MODE']),
    );
  }

  /// Opens a new physical connection. (Connection pooling is introduced in a
  /// later milestone; today each call opens and closes its own connection.)
  Future<Connection> connect() async {
    final parsedPort = int.tryParse(port);
    if (parsedPort == null) {
      throw ArgumentError('Invalid database port: "$port"');
    }
    return await Connection.open(
      Endpoint(
        host: host,
        database: databaseName,
        username: username,
        password: password,
        port: parsedPort,
      ),
      settings: ConnectionSettings(sslMode: sslMode),
    );
  }
}
