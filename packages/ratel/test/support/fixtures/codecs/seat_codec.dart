import 'package:ratel/runtime.dart';

import '../models/seat.dart';

abstract final class SeatCodec {
  static const definition = JsonCodecDefinition<Seat>(
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(Seat value) =>
      {'row': value.row, 'label': value.label};

  static Seat _decode(Map<String, Object?> json) => Seat(
        JsonValues.integer(json['row'], 'row'),
        JsonValues.string(json['label'], 'label'),
      );
}
