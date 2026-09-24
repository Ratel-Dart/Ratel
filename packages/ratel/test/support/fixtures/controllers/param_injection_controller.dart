import 'package:ratel/ratel.dart';

final class ParamInjectionController {
  Future<Response> header(String? user) async =>
      Response.json(data: {'user': user});

  Future<Response> cookie(String? session) async =>
      Response.json(data: {'session': session});
}
