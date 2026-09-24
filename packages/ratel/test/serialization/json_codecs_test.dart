import 'package:ratel/ratel.dart';
import 'package:test/test.dart';

import '../support/fixtures/codecs/greeting_codec.dart';
import '../support/fixtures/models/greeting.dart';

void main() {
  test('finds a codec by type', () {
    final codecs = JsonCodecs([GreetingCodec.definition]);
    expect(codecs.forType(Greeting), same(GreetingCodec.definition));
    expect(codecs.forType(String), isNull);
  });

  test('refuses two codecs for one type', () {
    expect(
      () => JsonCodecs([GreetingCodec.definition, GreetingCodec.definition]),
      throwsStateError,
    );
  });

  test('a response encodes registered types, nested ones included', () {
    final codecs = JsonCodecs([GreetingCodec.definition]);
    final response = Response.json(data: {
      'one': Greeting(message: 'a'),
      'many': [Greeting(message: 'b')],
    });
    expect(
      response.toJson(codecs: codecs),
      '{"one":{"message":"a"},"many":[{"message":"b"}]}',
    );
  });
}
