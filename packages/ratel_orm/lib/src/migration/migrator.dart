import '../driver/ratel_driver.dart';

import 'migration.dart';

class Migrator {
  final RatelDriver driver;

  final String table;

  Migrator(this.driver, {this.table = 'ratel_migrations'});

  Future<void> _ensureTable() async {
    await driver.query(
      'CREATE TABLE IF NOT EXISTS $table '
      '(id TEXT PRIMARY KEY, applied_at TEXT NOT NULL)',
    );
  }

  Future<Set<String>> appliedIds() async {
    await _ensureTable();
    final result = await driver.query('SELECT id FROM $table');
    return {for (final row in result.rows) row['id'] as String};
  }

  Future<List<String>> migrate(List<Migration> migrations) async {
    final applied = await appliedIds();
    final pending = migrations.where((m) => !applied.contains(m.id)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final result = <String>[];
    for (final migration in pending) {
      await driver.transaction((session) async {
        for (final statement in migration.up) {
          await session.query(statement);
        }
        await session.query(
          'INSERT INTO $table (id, applied_at) VALUES (@id, @at)',
          parameters: {'id': migration.id, 'at': _timestamp()},
        );
      });
      result.add(migration.id);
    }
    return result;
  }

  static String _timestamp() => DateTime.now().toUtc().toIso8601String();
}
