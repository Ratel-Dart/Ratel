import 'package:ratel/ratel.dart';

@Controller('/unbound')
class UnboundController {
  @Get('/:id')
  Future<Response> show(String id) async => Response.json(data: {'id': id});
}
