import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class TwoIdEntity {
  TwoIdEntity({required this.id, required this.code});

  @Id()
  final int id;
  @Id()
  final String code;
}
