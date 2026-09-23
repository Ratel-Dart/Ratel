import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

class _FakeDriver extends RatelDriver {
  bool opened = false;
  bool closed = false;
  String? lastSql;
  QueryResult next = const QueryResult();

  @override
  Future<void> open() async => opened = true;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<QueryResult> query(String sql,
      {Map<String, Object?>? parameters}) async {
    lastSql = sql;
    return next;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(RatelSession session) action) =>
      throw UnimplementedError();
}

class _ThrowingDriver extends _FakeDriver {
  @override
  Future<void> open() async => throw StateError('cannot connect');
}

void main() {
  test('configures and opens the driver before onStartup', () async {
    final fake = _FakeDriver();
    var openedBeforeStartup = false;
    final server = RatelServer(
      port: 0,
      database: fake,
      onStartup: () async => openedBeforeStartup = fake.opened,
    );
    await server.startServer();
    expect(fake.opened, isTrue);
    expect(openedBeforeStartup, isTrue);
    await server.stop();
    expect(fake.closed, isTrue);
  });

  test('startServer fails fast when the driver cannot open', () async {
    final server = RatelServer(port: 0, database: _ThrowingDriver());
    await expectLater(server.startServer(), throwsA(isA<StateError>()));
  });

  test('server.db runs raw SQL verbatim against the driver', () async {
    final fake = _FakeDriver()..next = const QueryResult(affectedRows: 2);
    final server = RatelServer(port: 0, database: fake);
    await server.startServer();
    final result = await server.db.query('DELETE FROM t');
    expect(fake.lastSql, 'DELETE FROM t');
    expect(result.affectedRows, 2);
    await server.stop();
  });
}
