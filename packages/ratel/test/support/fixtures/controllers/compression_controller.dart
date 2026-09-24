import 'package:ratel/ratel.dart';

final class CompressionController {
  Future<Response> data() async => Response.json(
        data: {'items': List.generate(200, (i) => 'item-$i')},
      );
}
