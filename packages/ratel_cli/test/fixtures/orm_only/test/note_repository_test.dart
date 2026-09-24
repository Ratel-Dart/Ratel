@Tags(['fixture'])
library;

import 'package:orm_only/entities/note.dart';
import 'package:orm_only/entities/note_status.dart';
import 'package:orm_only/repositories/note_repository.dart';
import 'package:orm_only/schema/notes_schema.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:test/test.dart';

void main() {
  late SqliteDriver driver;
  late NoteRepository notes;

  setUp(() async {
    driver = SqliteDriver.memory();
    await driver.open();
    await Migrator(driver).migrate(NotesSchema.migrations);
    notes = NoteRepository(driver);
  });

  tearDown(() => driver.close());

  test('stores a note and reads it back', () async {
    final created = await notes.insert(Note(
      title: 'Write tests',
      createdAt: DateTime.utc(2026, 5, 6),
      body: 'with the entity manifest',
    ));

    expect(created.id, isNotNull);
    final found = await notes.findById(created.id!);
    expect(found?.title, 'Write tests');
    expect(found?.status, NoteStatus.open);
    expect(found?.createdAt, DateTime.utc(2026, 5, 6));
    expect(found?.body, 'with the entity manifest');
    expect(found?.archived, isFalse);
  });

  test('updates and deletes a note', () async {
    final created = await notes.insert(Note(
      title: 'Ship it',
      createdAt: DateTime.utc(2026, 7, 8),
    ));

    final updated = await notes.update(created.withStatus(NoteStatus.done));
    expect(updated?.isDone, isTrue);
    expect(await notes.withStatus(NoteStatus.done), hasLength(1));
    expect(await notes.deleteById(created.id!), isTrue);
    expect(await notes.findById(created.id!), isNull);
  });
}
