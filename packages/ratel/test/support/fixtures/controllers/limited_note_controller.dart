import 'package:ratel/ratel.dart';

import '../models/limited_note.dart';

final class LimitedNoteController {
  Future<Response> ping() async => Response.json(data: {'ok': true});

  Future<Response> create(LimitedNote note) async =>
      Response.json(data: {'length': note.text.length});
}
