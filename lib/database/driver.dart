import 'query_result.dart';
import 'session.dart';

/// The contract every database driver implements.
///
/// This is a base class rather than an interface: drivers **extend** it so new
/// members can be added without breaking existing drivers. Concrete drivers
/// live in the `ratel_orm` package; the core stays database-agnostic.
///
/// Parameters use named placeholders (`@name`) matching the keys of the
/// `parameters` map. When `parameters` is null or empty the SQL is executed
/// verbatim, with no placeholder parsing.
abstract class RatelDriver {
  /// Connects or initializes the driver. Called once at startup; must be
  /// idempotent.
  Future<void> open();

  /// Releases resources held by the driver. Called at shutdown.
  Future<void> close();

  /// Executes [sql] with optional named [parameters] and returns the result.
  ///
  /// Accepted parameter values are `null`, `bool`, `int`, `double`, `String`,
  /// `DateTime` and `List<int>` (bytes); drivers encode them for their engine.
  /// Drivers must convert native engine exceptions into a `DatabaseException`.
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters});

  /// Runs [action] inside a transaction, committing when it completes and
  /// rolling back if it throws.
  Future<T> transaction<T>(Future<T> Function(RatelSession session) action);
}
