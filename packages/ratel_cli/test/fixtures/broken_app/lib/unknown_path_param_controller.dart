import 'package:ratel/ratel.dart';

@Controller('/users')
class UnknownPathParamController {
  @Get('/:id')
  Future<Response> show(@PathParam('userId') String id) async =>
      Response.json(data: {'id': id});
}
