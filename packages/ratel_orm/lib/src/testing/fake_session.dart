import 'package:ratel/ratel.dart' show QueryResult, RatelSession;

import 'fake_driver.dart';

/// The [RatelSession] a [FakeDriver] hands to a transaction body.
///
/// It delegates to the driver, so queued results and `errorToThrow` behave the
/// same inside a transaction as outside one.
class FakeSession implements RatelSession {
  final FakeDriver _driver;

  /// Wraps the driver running the transaction.
  FakeSession(this._driver);

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      _driver.query(sql, parameters: parameters);
}
