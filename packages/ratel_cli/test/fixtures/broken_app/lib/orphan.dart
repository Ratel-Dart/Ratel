import 'package:ratel/ratel.dart';

class Orphan {
  @Get('/orphan')
  Future<Response> orphan() async => Response.json(data: {});
}
