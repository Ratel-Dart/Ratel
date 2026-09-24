import 'package:ratel/runtime.dart';

import '../models/limited_note.dart';

abstract final class LimitedNoteCodec {
  static const definition = JsonCodecDefinition<LimitedNote>(
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(LimitedNote value) =>
      {'text': value.text};

  static LimitedNote _decode(Map<String, Object?> json) {
    final instance = LimitedNote();
    if (json.containsKey('text')) instance.text = json['text'] as String;
    return instance;
  }
}
