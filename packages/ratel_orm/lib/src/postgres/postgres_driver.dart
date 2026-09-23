import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:ratel/ratel.dart'
    show DatabaseException, QueryExecutionException, QueryResult, RatelSession;

import '../dialect.dart';
import '../orm_driver.dart';
import 'postgres_session.dart';
import 'query_result_mapper.dart';
import 'ssl_mode.dart';

/// An [OrmDriver] backed by `package:postgres`.
///
/// This is the only place in the ecosystem that imports `package:postgres`.
/// SQL is executed verbatim: named-parameter parsing (`@name`) is applied only
/// when [parameters] are supplied.
class PostgresDriver extends OrmDriver {
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

  /// Maximum number of pooled connections. Defaults to 10. With multi-isolate
  /// serving the real total is `maxConnections * isolates`.
  final int maxConnections;

  Pool? _pool;

  /// Creates a Postgres driver.
  PostgresDriver({
    required this.host,
    this.port = 5432,
    required this.databaseName,
    required this.username,
    required this.password,
    this.sslMode = SslMode.require,
    this.maxConnections = 10,
  });

  /// Builds the driver from environment variables: `DB_HOST`, `DB_PORT`
  /// (default `5432`), `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SSL_MODE`
  /// (`require` | `verify_full` | `disable`, default `require`) and
  /// `DB_POOL_MAX` (default `10`).
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

    final poolMax = int.tryParse(env['DB_POOL_MAX'] ?? '10');
    if (poolMax == null) {
      throw StateError('Invalid DB_POOL_MAX: "${env['DB_POOL_MAX']}"');
    }

    return PostgresDriver(
      host: required('DB_HOST'),
      port: port,
      databaseName: required('DB_NAME'),
      username: required('DB_USER'),
      password: required('DB_PASSWORD'),
      sslMode: parseSslMode(env['DB_SSL_MODE']),
      maxConnections: poolMax,
    );
  }

  Endpoint get _endpoint => Endpoint(
        host: host,
        database: databaseName,
        username: username,
        password: password,
        port: port,
      );

  PoolSettings get _poolSettings => PoolSettings(
        sslMode: sslMode,
        maxConnectionCount: maxConnections,
      );

  @override
  SqlDialect get dialect => const PostgresDialect();

  @override
  Future<void> open() async =>
      _pool ??= Pool.withEndpoints([_endpoint], settings: _poolSettings);

  @override
  Future<void> close() async {
    await _pool?.close();
    _pool = null;
  }

  Future<Pool> get _openPool async {
    await open();
    return _pool!;
  }

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    final pool = await _openPool;
    try {
      final result = (parameters == null || parameters.isEmpty)
          ? await pool.execute(sql)
          : await pool.execute(Sql.named(sql), parameters: parameters);
      return toQueryResult(result);
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw QueryExecutionException('Postgres query failed',
          sql: sql, cause: e);
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(RatelSession session) action,
  ) async {
    final pool = await _openPool;
    try {
      return await pool.runTx((tx) => action(PostgresSession(tx)));
    } on DatabaseException {
      rethrow;
    } catch (e) {
      throw QueryExecutionException(
        'Postgres transaction failed',
        sql: '',
        cause: e,
      );
    }
  }
}
