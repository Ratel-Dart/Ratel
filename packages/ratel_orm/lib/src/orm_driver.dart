import 'package:ratel/ratel.dart' show RatelDriver;

import 'dialect.dart';

/// A [RatelDriver] that carries a [SqlDialect].
///
/// Drivers shipped by `ratel_orm` extend this so the repository can translate
/// canonical SQL and honour engine quirks. Extending (not implementing) keeps
/// the contract growable without breaking drivers.
abstract class OrmDriver extends RatelDriver {
  /// The SQL dialect for this driver's engine.
  SqlDialect get dialect;
}
