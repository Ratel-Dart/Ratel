import 'package:ratel/ratel.dart';
import 'package:ratel_orm/ratel_orm.dart';

import 'controllers/users_controller.dart';
import 'repositories/user_repository.dart';

class OrmAppBindings extends Bindings {
  OrmAppBindings(this.driver);

  final RatelDriver driver;

  @override
  void dependencies() {
    Injector().put<UsersController>(
      () => UsersController(UserRepository(driver)),
    );
  }
}
