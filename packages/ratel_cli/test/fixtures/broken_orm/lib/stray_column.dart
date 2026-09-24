import 'package:ratel_orm/ratel_orm.dart';

final class StrayColumn {
  const StrayColumn(this.label);

  @Column(name: 'label_text')
  final String label;
}
