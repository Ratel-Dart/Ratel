import 'package:ratel_orm/ratel_orm.dart';

import 'account.dart';

final class LegacyRepository extends RatelRepository<Account> {
  LegacyRepository(super.driver);
}
