import 'package:ratel/ratel.dart';

import 'ticket.dart';

@Controller('/tickets')
class TicketController {
  @Post('/')
  Future<Response> redeem(@Body() Ticket ticket) async =>
      Response.json(data: {'code': ticket.code});
}
