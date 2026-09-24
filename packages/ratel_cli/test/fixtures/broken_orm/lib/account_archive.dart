import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'account')
final class AccountArchive {
  const AccountArchive({this.id, required this.owner});

  @Id()
  final int? id;
  final String owner;
}
