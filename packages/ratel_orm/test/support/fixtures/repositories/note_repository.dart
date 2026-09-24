import 'package:ratel_orm/ratel_orm.dart';

import '../entities/note.dart';

final class NoteRepository extends RatelRepository<Note> {
  NoteRepository(super.driver);

  @override
  Note fromRow(Map<String, Object?> row) =>
      Note(id: row['id'] as int, body: row['body'] as String);

  Future<List<Note>?> insert(int id, String body) => execute(
        'INSERT INTO notes (id, body) VALUES (@id, @body)',
        parameters: {'id': id, 'body': body},
        returning: true,
      );

  Future<List<Note>?> all() => execute('SELECT * FROM notes ORDER BY id');
}
