import 'package:ratel/ratel.dart' show QueryExecutionException;
import 'package:ratel_orm/ratel_orm.dart';
import 'package:ratel_orm/testing.dart';
import 'package:test/test.dart';

import '../support/fixtures/repositories/widget_repository.dart';

void main() {
  late FakeDriver fake;
  late WidgetRepository widgets;

  setUp(() {
    fake = FakeDriver();
    widgets = WidgetRepository(fake);
  });

  test('maps rows through fromRow', () async {
    fake.enqueueRows([
      {'id': 1, 'name': 'a'},
    ]);
    final found = await widgets.all();
    expect(found!.single.id, 1);
    expect(found.single.name, 'a');
  });

  test('empty result maps to null', () async {
    expect(await widgets.all(), isNull);
  });

  test('forwards parameters to the driver', () async {
    fake.enqueueRows([
      {'id': 5, 'name': 'b'},
    ]);
    await widgets.byId(5);
    expect(fake.lastParameters, {'id': 5});
  });

  test('driver error propagates untouched', () async {
    fake.errorToThrow = QueryExecutionException('boom', sql: 'x');
    await expectLater(
      widgets.all(),
      throwsA(isA<QueryExecutionException>()),
    );
  });

  test('unmappable row raises MappingException', () async {
    fake.enqueueRows([
      {'id': 'not-an-int', 'name': 'a'},
    ]);
    await expectLater(
      widgets.all(),
      throwsA(isA<MappingException>()),
    );
  });
}
