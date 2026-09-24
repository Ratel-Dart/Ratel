import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class UnbuildableEntity {
  UnbuildableEntity.create({required this.id});

  @Id()
  final int id;
}
