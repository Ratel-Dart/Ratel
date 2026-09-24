import 'package:ratel/runtime.dart';

import '../models/user_patch.dart';

abstract final class UserPatchCodec {
  static const definition = JsonCodecDefinition<UserPatch>(
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(UserPatch value) => {'name': value.name};

  static UserPatch _decode(Map<String, Object?> json) {
    final instance = UserPatch();
    if (json.containsKey('name')) instance.name = json['name'] as String;
    return instance;
  }
}
