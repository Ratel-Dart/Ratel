import 'dart:io';

import 'package:orm_only/entities/note.dart';
import 'package:orm_only/entities/note_status.dart';
import 'package:orm_only/repositories/note_repository.dart';
import 'package:orm_only/schema/notes_schema.dart';
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/sqlite.dart';

Future<void> main() async {
  final driver = SqliteDriver.memory();
  await driver.open();
  try {
    await Migrator(driver).migrate(NotesSchema.migrations);
    final notes = NoteRepository(driver);

    final created = await notes.insert(Note(
      title: 'Buy milk',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    ));
    stdout.writeln('created #${created.id} ${created.title} '
        '${created.status.name} ${created.createdAt.toIso8601String()}');

    final found = await notes.findById(created.id!);
    stdout.writeln('found #${found?.id} ${found?.title} body=${found?.body}');

    final updated = await notes
        .update(created.withStatus(NoteStatus.done)..archived = true);
    stdout.writeln('updated #${updated?.id} ${updated?.status.name} '
        'archived=${updated?.archived}');

    final done = await notes.withStatus(NoteStatus.done);
    stdout.writeln('done ${done.map((note) => note.title).join(', ')}');

    stdout.writeln('deleted ${await notes.deleteById(created.id!)}');
    stdout.writeln('remaining ${(await notes.findAll()).length}');
  } finally {
    await driver.close();
  }
}
