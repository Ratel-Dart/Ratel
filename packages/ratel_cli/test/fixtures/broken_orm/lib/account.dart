import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class Account {
  const Account({this.id, required this.owner});

  @Id()
  final int? id;
  final String owner;
}
