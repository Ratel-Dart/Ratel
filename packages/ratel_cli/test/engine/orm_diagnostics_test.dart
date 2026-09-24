@Tags(['orm'])
library;

import 'dart:io';

import 'package:ratel_cli/src/engine/diagnostics/diagnostic_codes.dart';
import 'package:ratel_cli/src/engine/diagnostics/ratel_diagnostic.dart';
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:test/test.dart';

import '../support/engine_harness.dart';
import '../support/orm_fixture.dart';

void main() {
  late Directory workspace;
  late GenerationResult result;

  setUpAll(() async {
    workspace = await Directory.systemTemp.createTemp('ratel_broken_orm');
    final app = await OrmFixture.copy('broken_orm', workspace);
    result = await EngineHarness.generateAt(
      app.path,
      packageName: 'broken_orm',
      entrypoint: 'bin/main.dart',
    );
  });

  tearDownAll(() => workspace.delete(recursive: true));

  RatelDiagnostic single(String code) =>
      result.diagnostics.singleWhere((diagnostic) => diagnostic.code == code);

  test('reports the broken entities and writes nothing', () {
    expect(result.hasErrors, isTrue);
    expect(result.files, isEmpty);
    expect(
      result.app.entities.map((entity) => entity.name),
      unorderedEquals(['Account', 'AccountArchive', 'PrivateFieldEntity']),
    );
  });

  final cases = <(String, String, int, String)>[
    (
      DiagnosticCodes.entityAbstract,
      'abstract_entity.dart',
      4,
      'The entity AbstractEntity is abstract',
    ),
    (
      DiagnosticCodes.entityGeneric,
      'generic_entity.dart',
      4,
      'The entity GenericEntity is generic',
    ),
    (
      DiagnosticCodes.entityNoId,
      'id_less_entity.dart',
      4,
      'The entity IdLessEntity has no @Id() field',
    ),
    (
      DiagnosticCodes.entityMultipleIds,
      'two_id_entity.dart',
      4,
      'The entity TwoIdEntity marks id, code with @Id()',
    ),
    (
      DiagnosticCodes.entityNotConstructible,
      'unbuildable_entity.dart',
      4,
      'UnbuildableEntity has no public unnamed constructor',
    ),
    (
      DiagnosticCodes.entityUnsettableField,
      'unsettable_entity.dart',
      9,
      'UnsettableEntity.code is final and not a constructor parameter',
    ),
    (
      DiagnosticCodes.entityUnsupportedType,
      'unsupported_entity.dart',
      9,
      'UnsupportedEntity.tags has type List<String>',
    ),
    (
      DiagnosticCodes.entityEmptyName,
      'nameless_entity.dart',
      4,
      'The entity NamelessEntity sets an empty table name',
    ),
    (
      DiagnosticCodes.entityColumnClash,
      'clashing_entity.dart',
      15,
      'ClashingEntity.owner maps to the column "owner_id", which '
          'ClashingEntity.ownerId already uses',
    ),
    (
      DiagnosticCodes.ormAnnotationMisplaced,
      'stray_column.dart',
      7,
      '@Column() on StrayColumn.label has no effect',
    ),
    (
      DiagnosticCodes.repositoryNotEntity,
      'plain_repository.dart',
      5,
      'PlainRepository stores PlainRecord, which is not an @Entity',
    ),
    (
      DiagnosticCodes.repositoryIdMismatch,
      'account_repository.dart',
      5,
      'Declare it as RatelRepository<Account, int>',
    ),
  ];

  for (final (code, file, line, message) in cases) {
    test('reports $code', () {
      final diagnostic = single(code);
      expect(diagnostic.isError, isTrue);
      expect(diagnostic.path, endsWith(file));
      expect(diagnostic.line, line);
      expect(diagnostic.message, contains(message));
    });
  }

  test('warns about two entities that share a table', () {
    final diagnostic = single(DiagnosticCodes.entityTableClash);
    expect(diagnostic.isError, isFalse);
    expect(diagnostic.path, endsWith('account_archive.dart'));
    expect(diagnostic.line, 4);
    expect(
      diagnostic.message,
      allOf([
        contains('package:broken_orm/account.dart'),
        contains('package:broken_orm/account_archive.dart'),
        contains('both map to the table "account"'),
      ]),
    );
  });

  test('warns about a private field without rejecting the entity', () {
    final diagnostic = single(DiagnosticCodes.entityPrivateField);
    expect(diagnostic.isError, isFalse);
    expect(diagnostic.path, endsWith('private_field_entity.dart'));
    expect(diagnostic.line, 9);
    expect(diagnostic.message, contains('@Transient()'));
  });

  test('explains the new type arguments of RatelRepository', () {
    final diagnostic = result.diagnostics.singleWhere(
      (diagnostic) => diagnostic.path.endsWith('legacy_repository.dart'),
    );
    expect(diagnostic.isError, isTrue);
    expect(diagnostic.code, 'wrong_number_of_type_arguments');
    expect(diagnostic.line, 5);
    expect(
      diagnostic.message,
      contains('RatelRepository now takes <T, ID>, e.g. '
          'RatelRepository<User, int>; rows are mapped from @Entity.'),
    );
  });
}
