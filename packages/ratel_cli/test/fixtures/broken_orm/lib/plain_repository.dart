import 'package:ratel_orm/ratel_orm.dart';

import 'plain_record.dart';

final class PlainRepository extends RatelRepository<PlainRecord, int> {
  PlainRepository(super.driver);
}
