import 'package:ratel/runtime.dart';

import '../controllers/strict_input_controller.dart';
import '../models/seat.dart';
import '../models/ticket.dart';

abstract final class StrictInputControllerDefinition {
  static const value = ControllerDefinition<StrictInputController>(
    create: StrictInputController.new,
    routes: [
      RouteDefinition<StrictInputController>(
        method: 'GET',
        path: '/search',
        parameters: [
          RouteParameter(
            name: 'q',
            location: ParameterLocation.query,
            type: String,
            isRequired: true,
          ),
        ],
        invoke: _search,
      ),
      RouteDefinition<StrictInputController>(
        method: 'GET',
        path: '/traced',
        parameters: [
          RouteParameter(
            name: 'X-Trace',
            location: ParameterLocation.header,
            type: String,
            isRequired: true,
          ),
        ],
        invoke: _traced,
      ),
      RouteDefinition<StrictInputController>(
        method: 'GET',
        path: '/session',
        parameters: [
          RouteParameter(
            name: 'session',
            location: ParameterLocation.cookie,
            type: String,
            isRequired: true,
          ),
        ],
        invoke: _session,
      ),
      RouteDefinition<StrictInputController>(
        method: 'POST',
        path: '/tickets',
        parameters: [
          RouteParameter(
            name: 'body',
            location: ParameterLocation.body,
            type: Ticket,
            isRequired: true,
          ),
        ],
        invoke: _create,
      ),
      RouteDefinition<StrictInputController>(
        method: 'POST',
        path: '/seats',
        parameters: [
          RouteParameter(
            name: 'seat',
            location: ParameterLocation.body,
            type: Seat,
            isRequired: true,
          ),
        ],
        invoke: _reserve,
      ),
    ],
  );

  static Object? _search(
    StrictInputController controller,
    List<Object?> arguments,
  ) =>
      controller.search(arguments[0] as String);

  static Object? _traced(
    StrictInputController controller,
    List<Object?> arguments,
  ) =>
      controller.traced(arguments[0] as String);

  static Object? _session(
    StrictInputController controller,
    List<Object?> arguments,
  ) =>
      controller.session(arguments[0] as String);

  static Object? _create(
    StrictInputController controller,
    List<Object?> arguments,
  ) =>
      controller.create(arguments[0] as Ticket);

  static Object? _reserve(
    StrictInputController controller,
    List<Object?> arguments,
  ) =>
      controller.reserve(arguments[0] as Seat);
}
