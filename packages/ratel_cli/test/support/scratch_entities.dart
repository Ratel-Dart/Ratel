abstract final class ScratchEntities {
  static const ormStub = {
    'lib/ratel_orm.dart': '''
class Entity {
  const Entity({this.table});

  final String? table;
}

class Column {
  const Column({this.name});

  final String? name;
}

class Id {
  const Id();
}

class Transient {
  const Transient();
}

abstract class RatelRepository<T extends Object, ID extends Object> {
  RatelRepository(this.driver);

  final Object driver;
}
''',
    'lib/runtime.dart': r'''
import 'dart:typed_data';

abstract final class RatelOrmRuntime {
  static const int contract = 1;

  static EntityManifest? _installed;

  static EntityManifest? get installed => _installed;

  static void install(EntityManifest manifest) {
    final current = _installed;
    if (current == null) {
      _installed = manifest;
      return;
    }
    if (identical(current, manifest)) return;
    throw StateError('A different manifest is already installed.');
  }
}

final class EntityManifest {
  const EntityManifest({this.entities = const []});

  final List<EntityDefinition<Object>> entities;
}

final class EntityDefinition<T extends Object> {
  const EntityDefinition({
    required this.name,
    this.table,
    required this.columns,
    required this.fromRow,
    required this.toRow,
  });

  final String name;
  final String? table;
  final List<ColumnDefinition> columns;
  final T Function(EntityRow row) fromRow;
  final Map<String, Object?> Function(T entity) toRow;

  Map<String, Object?> rowOf(Object entity) => toRow(entity as T);
}

final class ColumnDefinition {
  const ColumnDefinition({required this.field, this.name, this.isId = false});

  final String field;
  final String? name;
  final bool isId;
}

final class EntityRow {
  EntityRow(this._entity, this._values);

  final EntityDefinition<Object> _entity;
  final Map<String, Object?> _values;

  int integer(String field) => _read(field)! as int;
  int? integerOrNull(String field) => _read(field) as int?;
  double real(String field) => (_read(field)! as num).toDouble();
  double? realOrNull(String field) => (_read(field) as num?)?.toDouble();
  num number(String field) => _read(field)! as num;
  num? numberOrNull(String field) => _read(field) as num?;
  String text(String field) => _read(field)! as String;
  String? textOrNull(String field) => _read(field) as String?;
  bool boolean(String field) => _read(field)! as bool;
  bool? booleanOrNull(String field) => _read(field) as bool?;
  DateTime dateTime(String field) => DateTime.parse(_read(field)! as String);
  DateTime? dateTimeOrNull(String field) =>
      switch (_read(field)) { null => null, final value => DateTime.parse(value as String) };
  Uint8List bytes(String field) =>
      Uint8List.fromList((_read(field)! as List).cast<int>());
  Uint8List? bytesOrNull(String field) =>
      switch (_read(field)) { null => null, final value => Uint8List.fromList((value as List).cast<int>()) };
  E enumeration<E extends Enum>(String field, List<E> values) =>
      values.byName(_read(field)! as String);
  E? enumerationOrNull<E extends Enum>(String field, List<E> values) =>
      switch (_read(field)) { null => null, final value => values.byName(value as String) };

  Object? _read(String field) {
    final column = _entity.columns.firstWhere((column) => column.field == field);
    final name = column.name ??
        field.replaceAllMapped(RegExp('[A-Z]'), (match) => '_${match[0]!.toLowerCase()}');
    if (!_values.containsKey(name)) throw StateError('No column $name.');
    return _values[name];
  }
}
''',
  };

  static const legacyOrmStub = {
    'lib/ratel_orm.dart': '''
abstract class RatelRepository<T> {
  RatelRepository(this.driver);

  final Object driver;
}
''',
  };

  static const futureOrmStub = {
    'lib/ratel_orm.dart': '''
class Entity {
  const Entity();
}
''',
    'lib/runtime.dart': '''
abstract final class RatelOrmRuntime {
  static const int contract = 2;
}
''',
  };

  static const bookshelf = {
    'lib/entities/note.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: 'notes')
class Note {
  Note({this.id, required this.text});

  @Id()
  final int? id;
  final String text;
}
''',
    'lib/notes_controller.dart': '''
import 'package:ratel/ratel.dart';

import 'entities/note.dart';

@Controller('/notes')
class NotesController {
  @Get('/')
  Future<List<Note>> list() async => [Note(id: 1, text: 'a')];
}
''',
    'bin/server.dart': r'''
import 'package:ratel_orm/runtime.dart';

void main() {
  print('entities ${RatelOrmRuntime.installed?.entities.length}');
}
''',
    'tool/probe.dart': r'''
import 'dart:isolate';

import 'package:ratel/runtime.dart';
import 'package:ratel_orm/runtime.dart';

import '../.dart_tool/ratel/build/ratel_app_manifest.dart';
import '../.dart_tool/ratel/build/ratel_entity_manifest.dart';

Future<void> main() async {
  final spawned = await Isolate.run(() {
    RatelRuntime.install(RatelAppManifest.manifest);
    return identical(RatelOrmRuntime.installed, RatelEntityManifest.manifest);
  });
  RatelRuntime.install(RatelAppManifest.manifest);
  final here = identical(RatelOrmRuntime.installed, RatelEntityManifest.manifest);
  print('$spawned $here');
}
''',
  };

  static const empty = {
    'lib/models/plain.dart': '''
class Plain {
  String? name;
}
''',
    'bin/main.dart': '''
void main() {}
''',
  };

  static const library = {
    'lib/entities/status.dart': '''
enum Status { draft, published }
''',
    'lib/entities/grade.dart': '''
enum Grade {
  low('LOW'),
  high('HIGH');

  const Grade(this.name);

  final String name;
}
''',
    'lib/entities/audited.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

abstract class Audited {
  @Column(name: 'changed_at')
  DateTime? updatedAt;
}
''',
    'lib/entities/versioned.dart': '''
mixin Versioned {
  int version = 1;
}
''',
    'lib/entities/book.dart': '''
import 'dart:typed_data';

import 'package:ratel_orm/ratel_orm.dart';

import 'audited.dart';
import 'grade.dart';
import 'status.dart';
import 'versioned.dart';

@Entity(table: 'books')
class Book extends Audited with Versioned {
  Book({
    this.id,
    required this.title,
    this.status = Status.draft,
    this.grade,
    this.price = 0,
    this.rating,
    this.cover,
    this.published = false,
    required this.createdAt,
    this.pages = const [],
    this.selected = false,
  });

  @Id()
  final int? id;
  @Column(name: 'book_title')
  final String title;
  final Status status;
  final Grade? grade;
  final double price;
  final num? rating;
  final Uint8List? cover;
  final bool published;
  final DateTime createdAt;
  final List<int> pages;
  String? note;
  late int copies;
  @Transient()
  final bool selected;

  @Transient()
  static int count = 0;

  @Transient()
  String get label => title.toUpperCase();

  @Transient()
  set label(String value) => note = value;
}
''',
    'lib/entities/tag.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import 'grade.dart';

@Entity()
class Tag(
  @Id() final String code,
  @Column(name: 'tag_label') final String label,
  final int? weight,
  final Grade grade,
);
''',
    'lib/entities/identified.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

abstract class Identified {
  Identified(this.id);

  @Id()
  final int id;
}
''',
    'lib/entities/author.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import 'identified.dart';

@Entity()
class Author extends Identified {
  Author(super.id, this.name, [int ignored = 5, this.age = 0]);

  final String name;
  final int age;
}
''',
    'lib/repositories/crud_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

abstract class CrudRepository<T extends Object> extends RatelRepository<T, int> {
  CrudRepository(super.driver);
}
''',
    'lib/repositories/book_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import '../entities/book.dart';

class BookRepository extends RatelRepository<Book, int> {
  BookRepository(super.driver);
}
''',
    'lib/repositories/tag_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import '../entities/tag.dart';

class TagRepository extends RatelRepository<Tag, String> {
  TagRepository(super.driver);
}
''',
    'lib/repositories/author_repository.dart': '''
import '../entities/author.dart';
import 'crud_repository.dart';

class AuthorRepository extends CrudRepository<Author> {
  AuthorRepository(super.driver);
}
''',
    'bin/main.dart': '''
void main() {}
''',
    'tool/probe.dart': r'''
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ratel_orm/runtime.dart';

import '../.dart_tool/ratel/build/ratel_entity_manifest.dart';

void main() {
  RatelOrmRuntime.install(RatelEntityManifest.manifest);
  const rows = {
    'Book': {
      'id': 7,
      'book_title': 'Dune',
      'status': 'published',
      'grade': 'high',
      'price': 12,
      'rating': 4.5,
      'cover': [1, 2],
      'published': true,
      'created_at': '2026-01-02T03:04:05.000Z',
      'pages': [3, 4],
      'note': 'n',
      'copies': 2,
      'changed_at': null,
      'version': 3,
    },
    'Tag': {'code': 'sf', 'tag_label': 'Sci-fi', 'weight': null, 'grade': 'low'},
    'Author': {'id': 1, 'name': 'Frank', 'age': 60},
  };
  final mapped = <String, Object?>{};
  for (final definition in RatelEntityManifest.manifest.entities) {
    final entity = definition.fromRow(EntityRow(definition, rows[definition.name]!));
    final row = definition.rowOf(entity);
    mapped[definition.name] = {
      'type': '${entity.runtimeType}',
      'fields': [for (final column in definition.columns) column.field],
      'row': row,
    };
  }
  stdout.writeln(jsonEncode(mapped, toEncodable: (value) => switch (value) {
        DateTime() => value.toUtc().toIso8601String(),
        Uint8List() => [...value],
        _ => '$value',
      }));
}
''',
  };

  static const broken = {
    'lib/models/plain.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

class Plain {
  @Column()
  String? name;
}
''',
    'lib/entities/abstract_entity.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
abstract class AbstractEntity {
  @Id()
  int? id;
}
''',
    'lib/entities/generic_entity.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class GenericEntity<T> {
  @Id()
  int? id;
  T? value;
}
''',
    'lib/entities/hidden.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class _Hidden {
  @Id()
  int? id;
}

''',
    'lib/entities/no_id.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class NoId {
  NoId(this.name);

  final String name;
}
''',
    'lib/entities/two_ids.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class TwoIds {
  TwoIds(this.a, this.b);

  @Id()
  final int a;
  @Id()
  final int b;
}
''',
    'lib/entities/unbuildable.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Unbuildable {
  Unbuildable.make(this.id);

  @Id()
  final int id;
}
''',
    'lib/entities/secretive.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Secretive {
  Secretive(this.id, String token) : hash = token.hashCode;

  @Id()
  final int id;
  @Transient()
  final int hash;
}
''',
    'lib/entities/frozen.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Frozen {
  Frozen(this.id);

  @Id()
  final int id;
  final DateTime createdAt = DateTime.now();
}
''',
    'lib/entities/odd.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Odd {
  Odd(this.id, this.tags);

  @Id()
  final int id;
  final List<String> tags;
}
''',
    'lib/entities/keeper.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Keeper {
  Keeper(this.id);

  @Id()
  final int id;
  int _count = 0;

  int bump() => ++_count;
}
''',
    'lib/entities/getterish.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Getterish {
  Getterish(this.id);

  @Id()
  final int id;

  @Column()
  int get twice => id * 2;
}
''',
    'lib/entities/confused.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Confused {
  Confused(this.id);

  @Id()
  @Transient()
  final int id;
}
''',
    'lib/entities/clashing.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Clashing {
  Clashing(this.id, this.userId, this.owner);

  @Id()
  final int id;
  final int userId;
  @Column(name: 'user_id')
  final int owner;
}
''',
    'lib/entities/nameless.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity(table: '')
class Nameless {
  Nameless(this.id, this.label);

  @Id()
  final int id;
  @Column(name: '')
  final String label;
}
''',
    'lib/entities/sealed_column.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class SealedColumn {
  SealedColumn(this.id);

  @Id()
  final int id;
  @Column(name: 'secret_hash')
  String _hash = '';

  String get hash => _hash;
}
''',
    'lib/entities/private_id.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class PrivateId {
  @Id()
  int? _id;

  int? get id => _id;
}
''',
    'lib/entities/typo.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Typo {
  Typo(this.id, this.when, this.also);

  @Id()
  final int id;
  final DateTme when;
  final List<DateTme> also;
}
''',
    'lib/entities/orphan_base.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

abstract class OrphanBase {
  @Id()
  int? id;
}
''',
    'lib/entities/stamped.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

mixin Stamped {
  @Column(name: 'stamp')
  DateTime? stampedAt;
}
''',
    'lib/entities/static_column.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class StaticColumn {
  StaticColumn(this.id);

  @Id()
  final int id;

  @Column()
  @Transient()
  static int total = 0;
}
''',
    'lib/shop/item.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Item {
  Item(this.id);

  @Id()
  final int id;
}
''',
    'lib/blog/item.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

@Entity()
class Item {
  Item(this.id);

  @Id()
  final int id;
}
''',
    'lib/repositories/plain_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import '../models/plain.dart';

class PlainRepository extends RatelRepository<Plain, int> {
  PlainRepository(super.driver);
}
''',
    'lib/repositories/date_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

class DateRepository extends RatelRepository<DateTime, int> {
  DateRepository(super.driver);
}
''',
    'lib/repositories/base_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import '../entities/orphan_base.dart';

class BaseRepository extends RatelRepository<OrphanBase, int> {
  BaseRepository(super.driver);
}
''',
    'lib/repositories/keeper_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import '../entities/keeper.dart';

class KeeperRepository extends RatelRepository<Keeper, String> {
  KeeperRepository(super.driver);
}
''',
    'lib/repositories/legacy_repository.dart': '''
import 'package:ratel_orm/ratel_orm.dart';

import '../entities/keeper.dart';

class LegacyRepository extends RatelRepository<Keeper> {
  LegacyRepository(super.driver);
}
''',
  };
}
