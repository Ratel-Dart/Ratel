import 'package:ratel/ratel.dart';

@Json()
class Item {
  Item({this.id = 0, this.name = ''});

  int id;
  String name;

  String get label => '$id:$name';
}
