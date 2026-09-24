import 'package:ratel/ratel.dart';

@Controller('/health')
class HealthController {
  @Get('/')
  Future<Response> health() async => Response.json(data: {'ok': true});
}
