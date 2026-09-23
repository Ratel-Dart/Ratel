import 'package:ratel/ratel.dart' show QueryResult, RatelSession;

import 'sqlite_driver.dart';

/// A [RatelSession] scoped to a SQLite transaction.
///
/// SQLite runs in-process on a single connection, so the session delegates
/// straight back to the driver; the surrounding `BEGIN`/`COMMIT` is what makes
/// it transactional.
class SqliteSession implements RatelSession {
  final SqliteDriver _driver;

  /// Wraps the driver running the transaction.
  SqliteSession(this._driver);

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _driver.query(sql, parameters: parameters);
}
