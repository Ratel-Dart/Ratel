import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class PrivateFieldEntity {
  PrivateFieldEntity({required this.id});

  @Id()
  final int id;
  int _visits = 0;

  int get visits => _visits;

  void visit() => _visits++;
}
