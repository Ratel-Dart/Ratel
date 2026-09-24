import 'package:ratel/ratel.dart';

final class BoomController {
  Future<Response> boom() async => throw StateError('kaboom');
}
