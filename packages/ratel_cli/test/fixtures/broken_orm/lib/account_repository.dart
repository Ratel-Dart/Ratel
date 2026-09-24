import 'package:ratel_orm/ratel_orm.dart';

import 'account.dart';

final class AccountRepository extends RatelRepository<Account, String> {
  AccountRepository(super.driver);
}
