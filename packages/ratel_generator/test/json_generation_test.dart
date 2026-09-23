import 'package:test/test.dart';

import 'support/generator_harness.dart';

void main() {
  test('emits a toJson and a fromJson for a @Json class', () async {
    final output = await generate('app|lib/model.dart', {
      'app|lib/model.dart': '''
import 'package:ratel/annotations/annotations.dart';

@Json()
class Invoice {
  String reference = '';
  int amount = 0;
}
''',
    });

    expect(output, '''
import 'package:ratel/ratel.dart' as _r;
import 'model.dart';

Map<String, dynamic> \$InvoiceToJson(Invoice instance) => <String, dynamic>{
      'reference': instance.reference,
      'amount': instance.amount,
    };

Invoice \$InvoiceFromJson(Map<String, dynamic> json) {
  final instance = Invoice();
  if (json.containsKey('reference'))
    instance.reference = json['reference'] as String;
  if (json.containsKey('amount')) instance.amount = json['amount'] as int;
  return instance;
}

void \$registerRatel() {
  _r.RatelJson.register<Invoice>(\$InvoiceToJson);
}''');
  });

  test('serializes getters and skips private, static and final fields',
      () async {
    final output = await generate('app|lib/model.dart', {
      'app|lib/model.dart': '''
import 'package:ratel/annotations/annotations.dart';

@Json()
class Profile {
  static const version = 1;
  String name = '';
  final String slug = '';
  String _secret = '';

  String get display => name;
  String get _hidden => _secret;
}
''',
    });

    expect(output, contains("'name': instance.name,"));
    expect(output, contains("'slug': instance.slug,"));
    expect(output, contains("'display': instance.display,"));
    expect(output, isNot(contains('_secret')));
    expect(output, isNot(contains('_hidden')));
    expect(output, isNot(contains("'version'")));
    expect(output, contains("instance.name = json['name'] as String;"));
    expect(output, isNot(contains('instance.slug =')));
  });

  test('emits no fromJson when the class cannot be constructed', () async {
    final output = await generate('app|lib/model.dart', {
      'app|lib/model.dart': '''
import 'package:ratel/annotations/annotations.dart';

@Json()
class Token {
  Token(this.value);

  String value;
}
''',
    });

    expect(output, contains('\$TokenToJson'));
    expect(output, isNot(contains('\$TokenFromJson')));
  });

  test('uses the declared nullable type when reading a field', () async {
    final output = await generate('app|lib/model.dart', {
      'app|lib/model.dart': '''
import 'package:ratel/annotations/annotations.dart';

@Json()
class Note {
  String? body;
}
''',
    });

    expect(output, contains("instance.body = json['body'] as String?;"));
  });

  test('rejects a private @Json class', () async {
    final errors = await generateErrors('app|lib/model.dart', {
      'app|lib/model.dart': '''
import 'package:ratel/annotations/annotations.dart';

@Json()
class _Hidden {
  String name = '';
}
''',
    });

    expect(errors.join('\n'), contains('A @Json class must be public'));
  });
}
