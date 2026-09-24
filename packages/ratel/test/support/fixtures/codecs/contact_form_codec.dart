import 'package:ratel/runtime.dart';

import '../models/contact_form.dart';

abstract final class ContactFormCodec {
  static const definition = JsonCodecDefinition<ContactForm>(
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(ContactForm value) =>
      {'name': value.name, 'city': value.city};

  static ContactForm _decode(Map<String, Object?> json) {
    final instance = ContactForm();
    if (json.containsKey('name')) instance.name = json['name'] as String;
    if (json.containsKey('city')) instance.city = json['city'] as String;
    return instance;
  }
}
