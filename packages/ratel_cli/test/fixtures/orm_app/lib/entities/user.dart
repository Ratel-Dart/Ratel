import 'package:ratel_orm/ratel_orm.dart';

import 'user_role.dart';

@Entity(table: 'users')
final class User {
  const User({
    this.id,
    required this.email,
    required this.name,
    this.role = UserRole.member,
    required this.createdAt,
  });

  @Id()
  final int? id;
  @Column(name: 'e_mail')
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
}
