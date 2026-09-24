import 'package:ratel/ratel.dart';

import 'plain.dart';

@Controller('/bodies')
class BodiesController {
  @Post('/plain')
  Future<Response> plain(@Body() Plain body) async => Response.json(data: {});
}
