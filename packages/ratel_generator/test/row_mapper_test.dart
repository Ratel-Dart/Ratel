import 'package:test/test.dart';

import 'support/generator_harness.dart';

void main() {
  test('emits a row mapper for an @Column entity', () async {
    final output = await generate('app|lib/entity.dart', {
      'app|lib/entity.dart': '''
import 'package:ratel_orm/annotations.dart';

class Widget {
  @Column(name: 'id')
  int id = 0;

  @Column(name: 'name')
  String name = '';
}
''',
    });

    expect(output, '''
import 'package:ratel_orm/ratel_orm.dart' as _orm;
import 'entity.dart';

Widget \$WidgetFromRow(Map<String, Object?> row) {
  final entity = Widget();
  if (row.containsKey('id')) entity.id = row['id'] as int;
  if (row.containsKey('name')) entity.name = row['name'] as String;
  return entity;
}

void \$registerRatel() {
  _orm.RatelRowMappers.register<Widget>(\$WidgetFromRow);
}''');
  });

  test('lower-cases the column name', () async {
    final output = await generate('app|lib/entity.dart', {
      'app|lib/entity.dart': '''
import 'package:ratel_orm/annotations.dart';

class Account {
  @Column(name: 'DisplayName')
  String displayName = '';
}
''',
    });

    expect(
      output,
      stringContainsInOrder([
        "if (row.containsKey('displayname'))",
        "entity.displayName = row['displayname'] as String;",
      ]),
    );
  });

  test('maps only the annotated fields', () async {
    final output = await generate('app|lib/entity.dart', {
      'app|lib/entity.dart': '''
import 'package:ratel_orm/annotations.dart';

class Partial {
  @Column(name: 'id')
  int id = 0;

  String transient = '';
}
''',
    });

    expect(output, contains("row['id']"));
    expect(output, isNot(contains('transient')));
  });

  test('imports only the orm runtime when the file has no @Json or controller',
      () async {
    final output = await generate('app|lib/entity.dart', {
      'app|lib/entity.dart': '''
import 'package:ratel_orm/annotations.dart';

class Widget {
  @Column(name: 'id')
  int id = 0;
}
''',
    });

    expect(output, isNot(contains("import 'package:ratel/ratel.dart'")));
    expect(output, contains("import 'package:ratel_orm/ratel_orm.dart'"));
  });

  test('imports both runtimes when a file mixes @Json and @Column', () async {
    final output = await generate('app|lib/entity.dart', {
      'app|lib/entity.dart': '''
import 'package:ratel/annotations/annotations.dart';
import 'package:ratel_orm/annotations.dart';

@Json()
class Widget {
  @Column(name: 'id')
  int id = 0;
}
''',
    });

    expect(output, contains("import 'package:ratel/ratel.dart' as _r;"));
    expect(
        output, contains("import 'package:ratel_orm/ratel_orm.dart' as _orm;"));
    expect(output, contains('_r.RatelJson.register<Widget>'));
    expect(output, contains('_orm.RatelRowMappers.register<Widget>'));
  });

  test('matches @Column imported through the ratel_orm barrel library',
      () async {
    final output = await generate('app|lib/entity.dart', {
      'app|lib/entity.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

class Widget {
  @Column(name: 'id')
  int id = 0;
}
''',
    });

    expect(output, contains('\$WidgetFromRow'));
    expect(output, contains("row['id']"));
  });
}
