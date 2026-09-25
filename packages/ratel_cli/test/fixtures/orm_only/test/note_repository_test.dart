@Tags(['fixture'])
library;

import 'dart:typed_data';

import 'package:orm_only/entities/note.dart';
import 'package:orm_only/entities/note_status.dart';
import 'package:orm_only/repositories/note_repository.dart';
import 'package:orm_only/schema/notes_schema.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';
import 'package:ratel_orm/testing.dart';
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

  test('stores a List<int> field as bytes and reads it back', () async {
    final created = await notes.insert(Note(
      title: 'Attach',
      createdAt: DateTime.utc(2026, 9, 10),
      attachment: [1, 2, 255],
    ));

    final stored = await driver.query(
      'SELECT typeof(attachment) AS kind FROM notes WHERE id = @id',
      parameters: {'id': created.id},
    );
    expect(stored.rows.single['kind'], 'blob');
    final found = await notes.findById(created.id!);
    expect(found?.attachment, isA<Uint8List>());
    expect(found?.attachment, [1, 2, 255]);
  });

  test('hands the driver a List<int> field as a Uint8List', () async {
    final fake = FakeDriver();
    await NoteRepository(fake).update(Note(
      id: 1,
      title: 'Attach',
      createdAt: DateTime.utc(2026, 9, 10),
      attachment: [1, 2, 255],
    ));

    final bytes = fake.lastParameters?.values.whereType<Uint8List>();
    expect(bytes, [
      [1, 2, 255],
    ]);
  });
}
