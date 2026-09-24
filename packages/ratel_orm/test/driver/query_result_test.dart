import 'package:ratel_orm/ratel_orm.dart';
import 'package:test/test.dart';

void main() {
  test('defaults to empty with no metadata', () {
    const result = QueryResult();
    expect(result.rows, isEmpty);
    expect(result.isEmpty, isTrue);
    expect(result.affectedRows, 0);
    expect(result.lastInsertId, isNull);
  });

  test('holds rows and metadata', () {
    const result = QueryResult(
      rows: [
        {'id': 1, 'name': 'a'},
      ],
      affectedRows: 1,
      lastInsertId: 7,
    );
    expect(result.isEmpty, isFalse);
    expect(result.rows.single['name'], 'a');
    expect(result.affectedRows, 1);
    expect(result.lastInsertId, 7);
  });
}
