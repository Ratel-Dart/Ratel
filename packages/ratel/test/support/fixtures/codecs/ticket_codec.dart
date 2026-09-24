import 'package:ratel/runtime.dart';

import '../models/ticket.dart';

abstract final class TicketCodec {
  static const definition = JsonCodecDefinition<Ticket>(
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(Ticket value) => {'id': value.id};

  static Ticket _decode(Map<String, Object?> json) {
    final instance = Ticket();
    if (json.containsKey('id')) instance.id = json['id'] as int;
    return instance;
  }
}
