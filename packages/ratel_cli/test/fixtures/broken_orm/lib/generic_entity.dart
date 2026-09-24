import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class GenericEntity<T> {
  GenericEntity({required this.id});

  @Id()
  final int id;
}
