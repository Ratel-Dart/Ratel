import 'driver.dart';
import 'exceptions.dart';
import 'query_result.dart';
import 'session.dart';

/// Registry of the configured [RatelDriver] and entry point for raw SQL.
///
/// A single source of truth shared by the server's raw-SQL facade and the ORM
/// repository. Configure it once (the server does this at startup), then use an
/// instance to run raw SQL against the configured driver.
class Db {
  static RatelDriver? _driver;

  /// Registers [driver] as the active database driver.
  static void configure(RatelDriver driver) => _driver = driver;

  /// The configured driver.
  ///
  /// Throws [DatabaseNotConfiguredException] if no driver was configured.
  static RatelDriver get driver =>
      _driver ?? (throw const DatabaseNotConfiguredException());

  /// Creates a facade over the configured driver.
  const Db();

  /// Runs [sql] verbatim with optional named [parameters].
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      driver.query(sql, parameters: parameters);

  /// Runs [action] inside a transaction on the configured driver.
  Future<T> transaction<T>(Future<T> Function(RatelSession session) action) =>
      driver.transaction(action);
}
