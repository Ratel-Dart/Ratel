import 'package:ratel/ratel.dart';

@Controller('/bodies')
class BodiesController {
  @Post('/count')
  Future<Response> count(@Body() int count) async =>
      Response.json(data: {'count': count});
}
