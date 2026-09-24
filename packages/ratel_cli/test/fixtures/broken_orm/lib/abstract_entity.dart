import 'package:ratel_orm/ratel_orm.dart';

@Entity()
abstract class AbstractEntity {
  AbstractEntity({required this.id});

  @Id()
  final int id;
}
