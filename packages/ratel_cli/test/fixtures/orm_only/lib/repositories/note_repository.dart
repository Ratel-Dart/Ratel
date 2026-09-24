import 'package:ratel_orm/ratel_orm.dart';

import '../entities/note.dart';
import '../entities/note_status.dart';

final class NoteRepository extends RatelRepository<Note, int> {
  NoteRepository(super.driver);

  Future<List<Note>> withStatus(NoteStatus status) => execute(
        'SELECT * FROM notes WHERE status = @status ORDER BY id',
        parameters: {'status': status.name},
      );
}
