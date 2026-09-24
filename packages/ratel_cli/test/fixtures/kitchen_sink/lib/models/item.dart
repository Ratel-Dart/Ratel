import 'item_status.dart';
import 'tag.dart';

final class Item {
  const Item({
    required this.id,
    required this.name,
    this.tags = const [],
    this.status = ItemStatus.draft,
    this.createdAt,
  });

  final int id;
  final String name;
  final List<Tag> tags;
  final ItemStatus status;
  final DateTime? createdAt;

  String get label => '$id:$name';
}
