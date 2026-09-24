import 'package:ratel/ratel.dart';

import '../models/new_user.dart';

final class OpenApiDocController {
  Future<Response> byId(int id, String? format, String? trace) async =>
      Response.json(data: {});

  Future<Response> create(NewUser body) async =>
      Response.json(statusCode: 201, data: {});
}
