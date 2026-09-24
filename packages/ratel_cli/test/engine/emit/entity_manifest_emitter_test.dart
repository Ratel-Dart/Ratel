import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/emit/entity_manifest_emitter.dart';
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:test/test.dart';

import '../../support/generated_code.dart';
import '../../support/orm_package.dart';
import '../../support/scratch_entities.dart';
import '../../support/scratch_project.dart';

void main() {
  const expectedRows = {
    'Author': {
      'type': 'Author',
      'fields': ['id', 'name', 'age'],
      'row': {'id': 1, 'name': 'Frank', 'age': 60},
    },
    'Book': {
      'type': 'Book',
      'fields': [
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
        'note',
        'copies',
      ],
      'row': {
        'updatedAt': null,
        'version': 3,
        'id': 7,
        'title': 'Dune',
        'status': 'published',
        'grade': 'high',
        'price': 12.0,
        'rating': 4.5,
        'cover': [1, 2],
        'published': true,
        'createdAt': '2026-01-02T03:04:05.000Z',
        'pages': [3, 4],
        'note': 'n',
        'copies': 2,
      },
    },
    'Tag': {
      'type': 'Tag',
      'fields': ['code', 'label', 'weight', 'grade'],
      'row': {'code': 'sf', 'label': 'Sci-fi', 'weight': null, 'grade': 'low'},
    },
  };

  Future<(ScratchProject, GenerationResult)> generate(
    Map<String, Map<String, String>> packages, {
    Map<String, String> external = const {},
  }) async {
    final project = await ScratchProject.create(
      'library',
      ScratchEntities.library,
      packages: packages,
      external: external,
      framework: false,
    );
    final result = await project.generate(write: true);
    expect(result.hasErrors, isFalse, reason: '${result.diagnostics}');
    return (project, result);
  }

  group('against a stand-in ratel_orm', () {
    late ScratchProject project;
    late String manifest;
    late String source;

    setUpAll(() async {
      final (created, _) =
          await generate({'ratel_orm': ScratchEntities.ormStub});
      project = created;
      manifest = p.join(project.output, EntityManifestEmitter.file);
      source = File(manifest).readAsStringSync();
    });

    tearDownAll(() => project.dispose());

    test('imports only the ORM runtime and the entity libraries', () {
      expect(source, contains("import 'package:ratel_orm/runtime.dart' as o;"));
      expect(source, isNot(contains('package:ratel/')));
      expect(
        source,
        matches(
            RegExp(r"import 'package:library/entities/book\.dart' as i\d;")),
      );
    });

    test('describes each entity with its table and columns', () {
      expect(
        source,
        contains('      o.EntityDefinition<i1.Author>(\n'
            "        name: 'Author',\n"
            '        columns: [\n'
            "          o.ColumnDefinition(field: 'id', isId: true),\n"
            "          o.ColumnDefinition(field: 'name'),\n"
            "          o.ColumnDefinition(field: 'age'),\n"
            '        ],\n'
            '        fromRow: _authorFromRow,\n'
            '        toRow: _authorToRow,\n'
            '      ),\n'),
      );
      expect(source, contains("        table: 'books',\n"));
      expect(
        source,
        contains("o.ColumnDefinition(field: 'title', name: 'book_title')"),
      );
    });

    test('reads every column and passes skipped positional defaults', () {
      expect(
        source,
        contains('  static i1.Author _authorFromRow(o.EntityRow row) =>\n'
            '      i1.Author(\n'
            "        row.integer('id'),\n"
            "        row.text('name'),\n"
            '        5,\n'
            "        row.integer('age'),\n"
            '      );\n'),
      );
      expect(source, contains("        id: row.integerOrNull('id'),\n"));
      expect(
        source,
        matches(RegExp(
            r"status: row\.enumeration\('status', i\d\.Status\.values\)")),
      );
      expect(
        source,
        matches(RegExp(
            r"grade: row\.enumerationOrNull\('grade', i\d\.Grade\.values\)")),
      );
      expect(source, contains("        pages: row.bytes('pages'),\n"));
      expect(source, contains("        ..note = row.textOrNull('note')\n"));
      expect(source, contains("        ..copies = row.integer('copies');\n"));
    });

    test('writes every column under its field name, enums by name', () {
      expect(source, contains("        'status': entity.status.name,\n"));
      expect(
        source,
        contains("        'grade': switch (entity.grade) "
            '{ null => null, final value => EnumName(value).name },\n'),
      );
      expect(source, contains("        'createdAt': entity.createdAt,\n"));
    });

    test('generates code that analyzes cleanly, one class, no comments',
        () async {
      final problems = await GeneratedCode.problems([manifest]);
      expect(problems[manifest], isEmpty);
      expect(GeneratedCode.hasComments(manifest), isFalse);
      final declarations = GeneratedCode.declarations(manifest);
      expect(declarations, hasLength(1));
      expect(
        (declarations.single as ClassDeclaration).namePart.typeName.lexeme,
        EntityManifestEmitter.className,
      );
    });

    test('maps rows to entities and back', () async {
      final probe = await project.run('tool/probe.dart');
      expect(probe.exitCode, 0, reason: '${probe.stdout}${probe.stderr}');
      expect(jsonDecode('${probe.stdout}'), expectedRows);
    });
  });

  group('against the real ratel_orm', () {
    late ScratchProject project;
    late String manifest;

    setUpAll(() async {
      final (created, _) = await generate(const {},
          external: {'ratel_orm': await OrmPackage.root()});
      project = created;
      manifest = p.join(project.output, EntityManifestEmitter.file);
    });

    tearDownAll(() => project.dispose());

    test('generates code that analyzes cleanly', () async {
      final problems = await GeneratedCode.problems([manifest]);
      expect(problems[manifest], isEmpty);
    });

    test('maps rows to entities and back through its runtime', () async {
      final probe = await project.run('tool/probe.dart');
      expect(probe.exitCode, 0, reason: '${probe.stdout}${probe.stderr}');
      expect(jsonDecode('${probe.stdout}'), expectedRows);
    });
  }, tags: 'orm');
}
