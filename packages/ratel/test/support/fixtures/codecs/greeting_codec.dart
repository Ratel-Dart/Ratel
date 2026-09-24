import 'package:ratel/runtime.dart';

import '../models/greeting.dart';

abstract final class GreetingCodec {
  static const definition = JsonCodecDefinition<Greeting>(
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(Greeting value) =>
      {'message': value.message};

  static Greeting _decode(Map<String, Object?> json) =>
      Greeting(message: json['message'] as String? ?? '');
}
