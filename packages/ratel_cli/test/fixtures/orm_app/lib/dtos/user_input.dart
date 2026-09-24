import '../entities/user_role.dart';

final class UserInput {
  const UserInput({
    required this.email,
    required this.name,
    this.role = UserRole.member,
  });

  final String email;
  final String name;
  final UserRole role;
}
