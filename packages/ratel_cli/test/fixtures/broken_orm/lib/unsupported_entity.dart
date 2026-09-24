import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class UnsupportedEntity {
  UnsupportedEntity({required this.id, required this.tags});

  @Id()
  final int id;
  final List<String> tags;
}
