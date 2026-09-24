import 'package:ratel/ratel.dart';

import '../models/item.dart';
import '../models/item_status.dart';
import '../models/page.dart';
import '../models/tag.dart';

@Controller('/catalog')
class CatalogController {
  @Get('/featured')
  Future<Item> featured() async => Item(
        id: 1,
        name: 'lamp',
        tags: const [Tag(name: 'light'), Tag(name: 'desk')],
        status: ItemStatus.published,
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );

  @Get('/all')
  Future<List<Item>> all() async =>
      const [Item(id: 1, name: 'lamp'), Item(id: 2, name: 'chair')];

  @Get('/page')
  Future<Page<Item>> page() async =>
      const Page(items: [Item(id: 1, name: 'lamp')], total: 7);
}
