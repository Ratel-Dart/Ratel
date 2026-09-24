import 'package:ratel_orm/ratel_orm.dart';

@Entity()
final class IdLessEntity {
  IdLessEntity({required this.name});

  final String name;
}
