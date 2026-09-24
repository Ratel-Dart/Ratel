import 'package:ratel/ratel.dart' show RatelDriver;

import 'dialect.dart';

abstract class OrmDriver extends RatelDriver {
  SqlDialect get dialect;
}
