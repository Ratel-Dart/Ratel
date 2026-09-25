import 'package:ratel/ratel.dart';

import '../models/unprintable_failure.dart';

final class BoomController {
  Future<Response> boom() async => throw StateError('kaboom');

  Future<Response> unprintable() async => throw UnprintableFailure();
}
