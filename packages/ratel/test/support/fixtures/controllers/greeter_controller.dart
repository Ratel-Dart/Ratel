import 'package:ratel/ratel.dart';

final class GreeterController {
  GreeterController(this.salutation);

  final String salutation;

  Future<Response> greet() async => Response.text(data: salutation);
}
