import 'package:ratel_orm/ratel_orm.dart';

import '../entities/labeled_widget.dart';

final class LabeledWidgetRepository extends RatelRepository<LabeledWidget> {
  LabeledWidgetRepository(super.driver);

  @override
  LabeledWidget fromRow(Map<String, Object?> row) =>
      LabeledWidget(id: row['id'] as int, label: row['label'] as String);

  Future<List<LabeledWidget>?> insert(int id, String label) => execute(
        'INSERT INTO ratel_repo_widgets (id, label) VALUES (@id, @label)',
        parameters: {'id': id, 'label': label},
        returning: true,
      );
}
