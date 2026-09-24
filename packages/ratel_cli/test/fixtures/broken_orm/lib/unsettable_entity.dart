import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class UnsettableEntity {
  UnsettableEntity({required this.id}) : code = 'fixed';

  @Id()
  final int id;
  final String code;
}
