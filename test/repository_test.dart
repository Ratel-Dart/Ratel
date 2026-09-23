import 'package:ratel/ratel.dart' show QueryExecutionException;
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/testing.dart';
import 'package:test/test.dart';

import 'repository_test.ratel.dart';

class Widget {
  @Column(name: 'id')
  int id = 0;

  @Column(name: 'name')
  String name = '';
}

class WidgetRepo extends RatelRepository<Widget> {
  Future<List<Widget>?> all() => execute('SELECT * FROM widgets');

  Future<List<Widget>?> byId(int id) => execute(
        'SELECT * FROM widgets WHERE id = @id',
        substitutionValues: {'id': id},
      );
}

void main() {
  late FakeDriver fake;
  setUp(() {
    RatelRowMappers.reset();
    $registerRatel();
    fake = FakeDriver();
    RatelRepository.configure(fake);
  });

  test('maps rows via @Column', () async {
    fake.enqueueRows([
      {'id': 1, 'name': 'a'},
    ]);
    final widgets = await WidgetRepo().all();
    expect(widgets!.single.id, 1);
    expect(widgets.single.name, 'a');
  });

  test('empty result maps to null', () async {
    expect(await WidgetRepo().all(), isNull);
  });

  test('forwards substitution values to the driver', () async {
    fake.enqueueRows([
      {'id': 5, 'name': 'b'},
    ]);
    await WidgetRepo().byId(5);
    expect(fake.lastParameters, {'id': 5});
  });

  test('driver error propagates untouched', () async {
    fake.errorToThrow = QueryExecutionException('boom', sql: 'x');
    await expectLater(
      WidgetRepo().all(),
      throwsA(isA<QueryExecutionException>()),
    );
  });

  test('unmappable row raises MappingException', () async {
    fake.enqueueRows([
      {'id': 'not-an-int', 'name': 'a'},
    ]);
    await expectLater(
      WidgetRepo().all(),
      throwsA(isA<MappingException>()),
    );
  });
}
