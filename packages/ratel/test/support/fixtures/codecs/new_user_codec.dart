import 'package:ratel/runtime.dart';

import '../models/new_user.dart';

abstract final class NewUserCodec {
  static const definition = JsonCodecDefinition<NewUser>(
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(NewUser value) => {'name': value.name};

  static NewUser _decode(Map<String, Object?> json) {
    final instance = NewUser();
    if (json.containsKey('name')) instance.name = json['name'] as String;
    return instance;
  }
}
