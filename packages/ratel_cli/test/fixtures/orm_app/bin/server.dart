import 'dart:io';

import 'package:orm_app/orm_app_bindings.dart';
import 'package:orm_app/schema/users_schema.dart';
import 'package:ratel/ratel.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';

Future<void> main() async {
  final driver = SqliteDriver.memory();
  final server = RatelServer(
    port: int.parse(Platform.environment['PORT'] ?? '8080'),
    bindings: OrmAppBindings(driver),
    onStartup: () async {
      await driver.open();
      await Migrator(driver).migrate(UsersSchema.migrations);
    },
    onShutdown: driver.close,
  );
  await server.startServer();
  stdout.writeln('listening ${server.boundPort}');
}
