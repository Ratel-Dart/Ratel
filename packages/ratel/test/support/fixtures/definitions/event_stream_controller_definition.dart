import 'package:ratel/runtime.dart';

import '../controllers/event_stream_controller.dart';

abstract final class EventStreamControllerDefinition {
  static const value = ControllerDefinition<EventStreamController>(
    routes: [
      RouteDefinition<EventStreamController>(
        method: 'GET',
        path: '/events',
        invoke: _events,
      ),
      RouteDefinition<EventStreamController>(
        method: 'GET',
        path: '/ticks',
        invoke: _live,
      ),
      RouteDefinition<EventStreamController>(
        method: 'GET',
        path: '/held',
        invoke: _hold,
      ),
    ],
  );

  static Object? _events(
    EventStreamController controller,
    List<Object?> arguments,
  ) =>
      controller.events();

  static Object? _live(
    EventStreamController controller,
    List<Object?> arguments,
  ) =>
      controller.live();

  static Object? _hold(
    EventStreamController controller,
    List<Object?> arguments,
  ) =>
      controller.hold();
}
