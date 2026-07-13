import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:ratel/ratel.dart'
    show
        DatabaseException,
        QueryExecutionException,
        QueryResult,
        RatelDriver,
        RatelSession;

/// A [RatelDriver] backed by `package:postgres`.
///
/// This is the only place in the ecosystem that imports `package:postgres`.
/// SQL is executed verbatim: named-parameter parsing (`@name`) is applied only
/// when [parameters] are supplied.
class PostgresDriver extends RatelDriver {
  /// Database host name.
  final String host;

  /// Database port.
  final int port;

  /// Name of the database to connect to.
  final String databaseName;

  /// Authentication user name.
  final String username;

  /// Authentication password.
  final String password;

  /// TLS mode for the connection. Defaults to [SslMode.require].
  final SslMode sslMode;

  /// Creates a Postgres driver.
  PostgresDriver({
    required this.host,
    this.port = 5432,
    required this.databaseName,
    required this.username,
    required this.password,
    this.sslMode = SslMode.require,
  });

  /// Builds the driver from environment variables: `DB_HOST`, `DB_PORT`
  /// (default `5432`), `DB_NAME`, `DB_USER`, `DB_PASSWORD`, and `DB_SSL_MODE`
  /// (`require` | `verify_full` | `disable`, default `require`).
  factory PostgresDriver.fromEnv() {
    final env = Platform.environment;

    String required(String key) {
      final value = env[key];
      if (value == null || value.isEmpty) {
        throw StateError('Missing required environment variable: $key');
      }
      return value;
    }

    final port = int.tryParse(env['DB_PORT'] ?? '5432');
    if (port == null) {
      throw StateError('Invalid DB_PORT: "${env['DB_PORT']}"');
    }

    return PostgresDriver(
      host: required('DB_HOST'),
      port: port,
      databaseName: required('DB_NAME'),
      username: required('DB_USER'),
      password: required('DB_PASSWORD'),
      sslMode: _parseSslMode(env['DB_SSL_MODE']),
    );
  }

  Endpoint get _endpoint => Endpoint(
        host: host,
        database: databaseName,
        username: username,
        password: password,
        port: port,
      );

  ConnectionSettings get _settings => ConnectionSettings(sslMode: sslMode);

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    final connection = await Connection.open(_endpoint, settings: _settings);
    try {
      final result = (parameters == null || parameters.isEmpty)
          ? await connection.execute(sql)
          : await connection.execute(Sql.named(sql), parameters: parameters);
      return _toQueryResult(result);
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw QueryExecutionException('Postgres query failed',
          sql: sql, cause: e);
    } finally {
      await connection.close();
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(RatelSession session) action,
  ) async {
    final connection = await Connection.open(_endpoint, settings: _settings);
    try {
      return await connection.runTx((tx) => action(_PostgresSession(tx)));
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw QueryExecutionException(
        'Postgres transaction failed',
        sql: '',
        cause: e,
      );
    } finally {
      await connection.close();
    }
  }
}

class _PostgresSession implements RatelSession {
  final TxSession _tx;

  _PostgresSession(this._tx);

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    final result = (parameters == null || parameters.isEmpty)
        ? await _tx.execute(sql)
        : await _tx.execute(Sql.named(sql), parameters: parameters);
    return _toQueryResult(result);
  }
}

QueryResult _toQueryResult(Result result) => QueryResult(
      rows: [for (final row in result) row.toColumnMap()],
      affectedRows: result.affectedRows,
    );

SslMode _parseSslMode(String? value) {
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

/// Opt-in helper that appends `RETURNING *` to a write statement.
///
/// Trims a trailing `;` and adds `RETURNING *` to an INSERT/UPDATE/DELETE that
/// does not already have a RETURNING clause. Not applied automatically by
/// [PostgresDriver.query], which runs SQL verbatim.
String applyReturningClause(String sql) {
  var statement = sql.trim();
  if (statement.endsWith(';')) {
    statement = statement.substring(0, statement.length - 1);
  }
  final upper = statement.toUpperCase();
  final isWrite = upper.startsWith('INSERT') ||
      upper.startsWith('UPDATE') ||
      upper.startsWith('DELETE');
  if (isWrite && !upper.contains('RETURNING')) {
    statement += ' RETURNING *';
  }
  return statement;
}
