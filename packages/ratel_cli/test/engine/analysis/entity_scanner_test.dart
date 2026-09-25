import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/diagnostics/diagnostic_codes.dart';
import 'package:ratel_cli/src/engine/diagnostics/ratel_diagnostic.dart';
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:ratel_cli/src/engine/model/column_kind.dart';
import 'package:ratel_cli/src/engine/model/scanned_entity.dart';
import 'package:test/test.dart';

import '../../support/scratch_entities.dart';
import '../../support/scratch_project.dart';

void main() {
  late ScratchProject library;
  late ScratchProject broken;
  late GenerationResult mapped;
  late GenerationResult faulty;

  setUpAll(() async {
    library = await ScratchProject.create(
      'library',
      ScratchEntities.library,
      packages: {'ratel_orm': ScratchEntities.ormStub},
      framework: false,
    );
    broken = await ScratchProject.create(
      'broken',
      ScratchEntities.broken,
      packages: {'ratel_orm': ScratchEntities.ormStub},
      framework: false,
    );
    mapped = await library.generate();
    faulty = await broken.generate();
  });

  tearDownAll(() async {
    await library.dispose();
    await broken.dispose();
  });

  ScannedEntity entity(String name) =>
      mapped.app.entities.singleWhere((entity) => entity.name == name);

  List<RatelDiagnostic> reported(String code, String file) => [
        for (final diagnostic in faulty.diagnostics)
          if (diagnostic.code == code && p.basename(diagnostic.path) == file)
            diagnostic,
      ];

  RatelDiagnostic single(String code, String file) {
    final found = reported(code, file);
    expect(found, hasLength(1), reason: '$code in $file');
    return found.single;
  }

  test('maps every valid entity without diagnostics', () {
    expect(mapped.diagnostics, isEmpty);
    expect(
      mapped.app.entities.map((entity) => entity.name),
      unorderedEquals(['Author', 'Book', 'Tag']),
    );
  });

  test('makes every public instance field a column, inherited ones too', () {
    final book = entity('Book');
    expect(book.table, 'books');
    expect(book.columns.map((column) => column.field), [
      'updatedAt',
      'version',
      'id',
      'title',
      'status',
      'grade',
      'price',
      'rating',
      'cover',
      'published',
      'createdAt',
      'pages',
      'thumbnail',
      'note',
      'copies',
    ]);
    expect(book.id.field, 'id');
    final names = {
      for (final column in book.columns)
        if (column.name != null) column.field: column.name,
    };
    expect(names, {'updatedAt': 'changed_at', 'title': 'book_title'});
  });

  test('classifies the supported column types', () {
    final kinds = {
      for (final column in entity('Book').columns) column.field: column.kind,
    };
    expect(kinds, {
      'updatedAt': ColumnKind.dateTime,
      'version': ColumnKind.integer,
      'id': ColumnKind.integer,
      'title': ColumnKind.text,
      'status': ColumnKind.enumeration,
      'grade': ColumnKind.enumeration,
      'price': ColumnKind.real,
      'rating': ColumnKind.number,
      'cover': ColumnKind.bytes,
      'published': ColumnKind.boolean,
      'createdAt': ColumnKind.dateTime,
      'pages': ColumnKind.bytes,
      'thumbnail': ColumnKind.bytes,
      'note': ColumnKind.text,
      'copies': ColumnKind.integer,
    });
  });

  test('passes every covered column to the constructor and assigns the rest',
      () {
    final plan = entity('Book').construction;
    expect(
      plan.arguments.map((argument) => argument.property),
      [
        'id',
        'title',
        'status',
        'grade',
        'price',
        'rating',
        'cover',
        'published',
        'createdAt',
        'pages',
        'thumbnail',
      ],
    );
    expect(
      plan.assignments.map((field) => field.name),
      ['updatedAt', 'version', 'note', 'copies'],
    );
  });

  test('reads annotations from the parameters of a primary constructor', () {
    final tag = entity('Tag');
    expect(tag.id.field, 'code');
    expect(tag.columns.map((column) => column.field),
        ['code', 'label', 'weight', 'grade']);
    expect(tag.columns[1].name, 'tag_label');
    expect(tag.table, isNull);
  });

  test('takes the id from a superclass and keeps skipped positionals', () {
    final author = entity('Author');
    expect(author.id.field, 'id');
    expect(
      author.construction.arguments.map((argument) => argument.property),
      ['id', 'name', null, 'age'],
    );
  });

  test('reports an abstract entity', () {
    final found =
        single(DiagnosticCodes.entityAbstract, 'abstract_entity.dart');
    expect(found.isError, isTrue);
    expect(found.line, 4);
    expect(found.message, contains('AbstractEntity is abstract'));
  });

  test('reports a generic entity', () {
    final found = single(DiagnosticCodes.entityGeneric, 'generic_entity.dart');
    expect(found.message, contains('GenericEntity is generic'));
  });

  test('reports a private entity', () {
    final found = single(DiagnosticCodes.privateClass, 'hidden.dart');
    expect(found.message, contains('The entity _Hidden must be public'));
  });

  test('reports an entity without an id', () {
    final found = single(DiagnosticCodes.entityNoId, 'no_id.dart');
    expect(found.message, contains('NoId has no @Id() field'));
  });

  test('reports an entity with two ids', () {
    final found = single(DiagnosticCodes.entityMultipleIds, 'two_ids.dart');
    expect(found.message, contains('marks a, b with @Id()'));
  });

  test('reports an entity it cannot construct', () {
    expect(
      single(DiagnosticCodes.entityNotConstructible, 'unbuildable.dart')
          .message,
      contains('Unbuildable has no public unnamed constructor'),
    );
    expect(
      single(DiagnosticCodes.entityNotConstructible, 'secretive.dart').message,
      contains('the required constructor parameter token matches no column'),
    );
  });

  test('reports a final column no constructor parameter sets', () {
    final found = single(DiagnosticCodes.entityUnsettableField, 'frozen.dart');
    expect(found.line, 9);
    expect(
      found.message,
      allOf([
        contains('Frozen.createdAt is final and not a constructor parameter'),
        contains('@Transient()'),
      ]),
    );
  });

  test('reports a column type it cannot store', () {
    final found = single(DiagnosticCodes.entityUnsupportedType, 'odd.dart');
    expect(found.line, 9);
    expect(
      found.message,
      allOf(
          [contains('Odd.tags has type List<String>'), contains('@Transient')]),
    );
  });

  test('warns that a private field is not persisted', () {
    final found = single(DiagnosticCodes.entityPrivateField, 'keeper.dart');
    expect(found.isError, isFalse);
    expect(found.line, 9);
    expect(found.message, contains('Keeper._count is private'));
  });

  test('reports ORM annotations that have no effect', () {
    expect(
      single(DiagnosticCodes.ormAnnotationMisplaced, 'plain.dart').message,
      contains('Plain is not an @Entity'),
    );
    expect(
      single(DiagnosticCodes.ormAnnotationMisplaced, 'getterish.dart').message,
      contains('getters and setters never are'),
    );
    expect(
      single(DiagnosticCodes.ormAnnotationMisplaced, 'confused.dart').message,
      contains('marked both @Id() and @Transient()'),
    );
    expect(reported(DiagnosticCodes.entityNoId, 'confused.dart'), isEmpty);
  });

  test('accepts a redundant @Transient() on a member that is not a column', () {
    expect(
      mapped.diagnostics.where(
        (diagnostic) =>
            diagnostic.code == DiagnosticCodes.ormAnnotationMisplaced,
      ),
      isEmpty,
    );
    expect(
      single(DiagnosticCodes.ormAnnotationMisplaced, 'static_column.dart')
          .message,
      allOf([
        contains('@Column() on StaticColumn.total has no effect'),
        contains('static fields are never columns'),
        isNot(contains('@Transient()')),
      ]),
    );
  });

  test('reports two fields that map to one column', () {
    final found = single(DiagnosticCodes.entityColumnClash, 'clashing.dart');
    expect(found.isError, isTrue);
    expect(found.line, 11);
    expect(
      found.message,
      allOf([
        contains('Clashing.owner maps to the column "user_id"'),
        contains('which Clashing.userId already uses'),
        contains('@Column(name:'),
      ]),
    );
  });

  test('reports an empty table or column name', () {
    final found = reported(DiagnosticCodes.entityEmptyName, 'nameless.dart');
    expect(
        found.map((diagnostic) => diagnostic.line), unorderedEquals([4, 10]));
    expect(found.every((diagnostic) => diagnostic.isError), isTrue);
    expect(
      found.map((diagnostic) => diagnostic.message),
      unorderedEquals([
        contains('Nameless sets an empty table name'),
        contains('Nameless.label sets an empty column name'),
      ]),
    );
  });

  test('warns when two entities map to the same table', () {
    final found = reported(DiagnosticCodes.entityTableClash, 'item.dart');
    expect(found, hasLength(1));
    expect(found.single.isError, isFalse);
    expect(
      found.single.message,
      allOf([
        contains('package:broken/shop/item.dart'),
        contains('package:broken/blog/item.dart'),
        contains('both map to the table "item"'),
        contains('@Entity(table:'),
      ]),
    );
  });

  test('rejects a private field marked as a column or the id', () {
    final column =
        single(DiagnosticCodes.entityPrivateField, 'sealed_column.dart');
    expect(column.isError, isTrue);
    expect(
      column.message,
      contains('SealedColumn._hash is marked @Column(), but it is private'),
    );
    final id = single(DiagnosticCodes.entityPrivateField, 'private_id.dart');
    expect(id.isError, isTrue);
    expect(id.message, contains('PrivateId._id is marked @Id()'));
    expect(reported(DiagnosticCodes.entityNoId, 'private_id.dart'), isEmpty);
  });

  test('leaves an unresolved field type to the analyzer', () {
    final typo = [
      for (final diagnostic in faulty.diagnostics)
        if (p.basename(diagnostic.path) == 'typo.dart') diagnostic.code,
    ];
    expect(typo, contains('undefined_class'));
    expect(typo, everyElement(isNot(startsWith('ratel_'))));
  });

  test('points an annotation on an unmapped base at a concrete entity', () {
    expect(
      single(DiagnosticCodes.ormAnnotationMisplaced, 'orphan_base.dart')
          .message,
      allOf([
        contains('OrphanBase is abstract and no @Entity class extends it'),
        isNot(contains('Annotate the class with @Entity()')),
      ]),
    );
    expect(
      single(DiagnosticCodes.ormAnnotationMisplaced, 'stamped.dart').message,
      contains('no @Entity class mixes in Stamped'),
    );
  });

  test('writes nothing when an entity is broken', () {
    expect(faulty.hasErrors, isTrue);
    expect(faulty.files, isEmpty);
  });
}
