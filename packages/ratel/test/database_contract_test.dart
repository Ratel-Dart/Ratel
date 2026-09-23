import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _FakeDriver extends RatelDriver {
  bool opened = false;
  bool closed = false;
  String? lastSql;
  Map<String, Object?>? lastParameters;
  QueryResult next = const QueryResult();

  @override
  Future<void> open() async => opened = true;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    lastSql = sql;
    lastParameters = parameters;
    return next;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(RatelSession session) action) =>
      action(_FakeSession(this));
}

class _FakeSession implements RatelSession {
  final _FakeDriver driver;
  _FakeSession(this.driver);

  @override
  Future<QueryResult> query(String sql, {Map<String, Object?>? parameters}) =>
      driver.query(sql, parameters: parameters);
}

void main() {
  group('QueryResult', () {
    test('defaults to empty with no metadata', () {
      const result = QueryResult();
      expect(result.rows, isEmpty);
      expect(result.isEmpty, isTrue);
      expect(result.affectedRows, 0);
      expect(result.lastInsertId, isNull);
    });

    test('holds rows and metadata', () {
      final result = QueryResult(
        rows: [
          {'id': 1, 'name': 'a'},
        ],
        affectedRows: 1,
        lastInsertId: 7,
      );
      expect(result.isEmpty, isFalse);
      expect(result.rows.single['name'], 'a');
      expect(result.affectedRows, 1);
      expect(result.lastInsertId, 7);
    });
  });

  group('exceptions', () {
    test('QueryExecutionException carries sql and cause', () {
      final error =
          QueryExecutionException('boom', sql: 'SELECT 1', cause: 'root');
      expect(error, isA<DatabaseException>());
      expect(error.sql, 'SELECT 1');
      expect(error.cause, 'root');
      expect(error.toString(), contains('boom'));
    });

    test('subclasses are DatabaseException', () {
      expect(const DatabaseNotConfiguredException(), isA<DatabaseException>());
      expect(const DriverConnectionException('x'), isA<DatabaseException>());
    });
  });

  group('Db registry and facade', () {
    late _FakeDriver fake;
    setUp(() {
      fake = _FakeDriver();
      Db.configure(fake);
    });

    test('driver returns the configured driver', () {
      expect(Db.driver, same(fake));
    });

    test('query delegates verbatim to the driver', () async {
      fake.next = const QueryResult(affectedRows: 3);
      final result = await const Db()
          .query('DELETE FROM t WHERE k = @k', parameters: {'k': 1});
      expect(fake.lastSql, 'DELETE FROM t WHERE k = @k');
      expect(fake.lastParameters, {'k': 1});
      expect(result.affectedRows, 3);
    });

    test('transaction runs the action on a session', () async {
      final rows = await const Db().transaction(
        (session) => session.query('SELECT 1'),
      );
      expect(fake.lastSql, 'SELECT 1');
      expect(rows.isEmpty, isTrue);
    });
  });
}
