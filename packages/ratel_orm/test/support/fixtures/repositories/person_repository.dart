import 'package:ratel_orm/ratel_orm.dart';

import '../entities/person.dart';

final class PersonRepository extends RatelRepository<Person> {
  PersonRepository(super.driver);

  @override
  Person fromRow(Map<String, Object?> row) => Person(
        id: row['id'] as int,
        name: row['name'] as String,
        age: row['age'] as int,
      );
}
