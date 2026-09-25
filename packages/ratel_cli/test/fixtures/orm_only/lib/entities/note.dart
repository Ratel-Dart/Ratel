import 'package:ratel_orm/ratel_orm.dart';

import 'note_status.dart';

@Entity(table: 'notes')
final class Note {
  Note({
    this.id,
    required this.title,
    this.status = NoteStatus.open,
    required this.createdAt,
    this.body,
    this.attachment,
    this.selected = false,
  });

  @Id()
  final int? id;
  final String title;
  final NoteStatus status;
  @Column(name: 'created_on')
  final DateTime createdAt;
  final String? body;
  final List<int>? attachment;
  bool archived = false;
  @Transient()
  final bool selected;

  bool get isDone => status == NoteStatus.done;

  Note withStatus(NoteStatus next) => Note(
        id: id,
        title: title,
        status: next,
        createdAt: createdAt,
        body: body,
        attachment: attachment,
      )..archived = archived;
}
