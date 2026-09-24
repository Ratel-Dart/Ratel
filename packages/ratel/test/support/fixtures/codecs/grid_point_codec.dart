import 'package:ratel/runtime.dart';

import '../models/grid_point.dart';

abstract final class GridPointCodec {
  static const definition = JsonCodecDefinition<GridPoint>(encode: _encode);

  static Map<String, Object?> _encode(GridPoint value) =>
      {'x': value.x, 'y': value.y};
}
