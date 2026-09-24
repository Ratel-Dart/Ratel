import 'package:ratel/ratel.dart';

import '../models/user_patch.dart';

final class UsersController {
  Future<Response> getUser(int id) async => Response.json(data: {'id': id});

  Future<Response> patchUser(int id, UserPatch body) async =>
      Response.json(data: {'id': id, 'name': body.name});

  Future<Response> create() async =>
      Response.json(statusCode: 201, data: {'created': true});
}
