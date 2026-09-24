import 'package:ratel/ratel.dart';

@Controller('/static')
class StaticRouteController {
  @Get('/')
  static Future<Response> list() async => Response.json(data: {});
}
