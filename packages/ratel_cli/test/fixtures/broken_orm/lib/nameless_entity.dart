import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: '')
final class NamelessEntity {
  const NamelessEntity({required this.id});

  @Id()
  final int id;
}
