import 'package:ratel/ratel.dart';

final class EventStreamController {
  EventStreamController(this.ticks, this.held);

  final Stream<String> ticks;
  final Stream<String> held;

  Future<Response> events() async =>
      Response.sse(Stream.fromIterable(['a', 'b', 'c']));

  Future<Response> live() async => Response.sse(ticks);

  Future<Response> hold() async => Response.sse(held);
}
