import 'dart:ffi';

import 'package:sqlite3/open.dart';

abstract final class SqliteTestLibrary {
  static void useSystemLibrary() => open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
}
