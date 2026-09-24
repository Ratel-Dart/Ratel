import 'package:ratel/runtime.dart';

import '../controllers/limited_note_controller.dart';
import '../models/limited_note.dart';

abstract final class LimitedNoteControllerDefinition {
  static const value = ControllerDefinition<LimitedNoteController>(
    create: LimitedNoteController.new,
    routes: [
      RouteDefinition<LimitedNoteController>(
        method: 'GET',
        path: '/ping',
        invoke: _ping,
      ),
      RouteDefinition<LimitedNoteController>(
        method: 'POST',
        path: '/notes',
        parameters: [
          RouteParameter(
            name: 'note',
            location: ParameterLocation.body,
            type: LimitedNote,
            isRequired: true,
          ),
        ],
        invoke: _create,
      ),
    ],
  );

  static Object? _ping(
    LimitedNoteController controller,
    List<Object?> arguments,
  ) =>
      controller.ping();

  static Object? _create(
    LimitedNoteController controller,
    List<Object?> arguments,
  ) =>
      controller.create(arguments[0] as LimitedNote);
}
