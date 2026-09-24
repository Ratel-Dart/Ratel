import 'package:ratel_orm/ratel_orm.dart';

import '../entities/user.dart';

final class UserRepository extends RatelRepository<User, int> {
  UserRepository(super.driver);
}
