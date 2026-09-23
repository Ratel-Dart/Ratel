import 'package:test/test.dart';

import 'support/generator_harness.dart';

void main() {
  test('writes nothing for a library with no Ratel annotations', () async {
    final paths = await generatedPaths('app|lib/plain.dart', {
      'app|lib/plain.dart': '''
class Plain {
  String name = '';
}
''',
    });

    expect(paths, isEmpty);
  });

  test('writes nothing for a class annotated with an unrelated annotation',
      () async {
    final paths = await generatedPaths('app|lib/plain.dart', {
      'app|lib/plain.dart': '''
class Json {
  const Json();
}

@Json()
class Plain {
  String name = '';
}
''',
    });

    expect(paths, isEmpty);
  });
}
