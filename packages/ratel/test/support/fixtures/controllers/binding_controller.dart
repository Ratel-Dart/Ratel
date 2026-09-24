import 'dart:io';

import 'package:ratel/ratel.dart';

import '../models/greeting.dart';

final class BindingController {
  Future<Response> item(
    int id,
    String? filter,
    String? trace,
    String? session,
  ) async =>
      Response.json(data: {
        'id': id,
        'filter': filter,
        'trace': trace,
        'session': session,
      });

  Future<Response> me(RequestContext ctx) async =>
      Response.json(data: {'path': ctx.path});

  Future<Response> echo(Greeting body) async => Response.json(data: body);

  Future<Response> upload(MultipartData form, Greeting body) async =>
      Response.json(data: {
        'files': form.files.length,
        'message': body.message,
      });

  String plain() => 'plain';

  Future<void> chat(WebSocket socket, RequestContext ctx) async {
    socket.add('hello ${ctx.path}');
    await socket.close();
  }
}
