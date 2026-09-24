import 'package:ratel_orm/ratel_orm.dart';

abstract final class NotesSchema {
  static const migrations = [
    Migration(
      id: '001_create_notes',
      up: [
        'CREATE TABLE notes ('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'title TEXT NOT NULL, '
            'status TEXT NOT NULL, '
            'created_on TEXT NOT NULL, '
            'body TEXT, '
            'archived INTEGER NOT NULL)',
      ],
    ),
  ];
}
