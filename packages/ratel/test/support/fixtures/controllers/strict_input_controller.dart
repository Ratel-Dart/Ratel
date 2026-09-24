import 'package:ratel/ratel.dart';

import '../models/ticket.dart';

final class StrictInputController {
  Future<Response> search(String q) async => Response.json(data: {'q': q});

  Future<Response> traced(String trace) async =>
      Response.json(data: {'trace': trace});

  Future<Response> session(String session) async =>
      Response.json(data: {'session': session});

  Future<Response> create(Ticket body) async => Response.json(data: body);
}
