import 'package:ratel/ratel.dart';

@Json()
class Greeting {
  Greeting({this.message = ''});

  String message;
}
