import 'package:ratel_orm/ratel_orm.dart';

import '../entities/widget.dart';

final class WidgetRepository extends RatelRepository<Widget> {
  WidgetRepository(super.driver);

  @override
  Widget fromRow(Map<String, Object?> row) =>
      Widget(id: row['id'] as int, name: row['name'] as String);

  Future<List<Widget>?> all() => execute('SELECT * FROM widgets');

  Future<List<Widget>?> byId(int id) => execute(
        'SELECT * FROM widgets WHERE id = @id',
        parameters: {'id': id},
      );
}
