import 'driver.dart';
import 'exceptions.dart';
import 'query_result.dart';
import 'session.dart';

/// Entry point for raw SQL against a [RatelDriver].
///
/// A [Db] built with a driver runs against that one — `server.db` hands out a
/// facade over the server's own driver. A [Db] built without one falls back to
/// the driver registered with [configure], which is what the ORM repository
/// resolves through.
class Db {
  static RatelDriver? _ambient;

  final RatelDriver? _driver;

  /// Creates a facade over [driver], or over the registered driver when it is
  /// null.
  const Db([RatelDriver? driver]) : _driver = driver;

  /// Registers [driver] as the driver a [Db] without one resolves to.
  static void configure(RatelDriver driver) => _ambient = driver;

  /// The registered driver.
  ///
  /// Throws [DatabaseNotConfiguredException] if no driver was configured.
  static RatelDriver get driver =>
      _ambient ?? (throw const DatabaseNotConfiguredException());

  RatelDriver get _resolved => _driver ?? driver;

  /// Runs [sql] verbatim with optional named [parameters].
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _resolved.query(sql, parameters: parameters);

  /// Runs [action] inside a transaction on the resolved driver.
  Future<T> transaction<T>(Future<T> Function(RatelSession session) action) =>
      _resolved.transaction(action);
}
