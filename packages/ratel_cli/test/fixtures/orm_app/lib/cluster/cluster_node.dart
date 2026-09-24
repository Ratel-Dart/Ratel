import 'dart:async';
import 'dart:io';

import 'package:ratel/ratel.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';

import '../entities/user.dart';
import '../orm_app_bindings.dart';
import '../repositories/user_repository.dart';
import '../schema/users_schema.dart';

abstract final class ClusterNode {
  static void start(List<String> args) => unawaited(_serve());

  static Future<void> _serve() async {
    final driver = SqliteDriver.memory();
    await driver.open();
    await Migrator(driver).migrate(UsersSchema.migrations);
    final seeded = await UserRepository(driver).insert(User(
      email: 'node@example.com',
      name: 'Node',
      createdAt: DateTime.utc(2026),
    ));
    stdout.writeln('mapped ${seeded.email} #${seeded.id}');
    final server = RatelServer(
      port: int.parse(Platform.environment['PORT'] ?? '8080'),
      shared: true,
      bindings: OrmAppBindings(driver),
      onShutdown: driver.close,
    );
    await server.startServer();
  }
}
