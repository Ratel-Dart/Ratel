import 'package:ratel_orm/ratel_orm.dart';

abstract final class UsersSchema {
  static const migrations = [
    Migration(
      id: '001_create_users',
      up: [
        'CREATE TABLE users ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'e_mail TEXT NOT NULL UNIQUE, '
            'name TEXT NOT NULL, '
            'role TEXT NOT NULL, '
            'created_at TEXT NOT NULL)',
      ],
    ),
  ];
}
