import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/process/dart_sdk.dart';
import 'package:test/test.dart';

import '../../support/scratch_apps.dart';
import '../../support/scratch_project.dart';

void main() {
  group('a newsroom app', () {
    late ScratchProject project;
    late String manifest;
    late Map<String, Object?> probe;

    setUpAll(() async {
      project = await ScratchProject.create('newsroom', ScratchApps.newsroom);
      final result = await project.generate(write: true);
      expect(result.hasErrors, isFalse, reason: '${result.diagnostics}');
      manifest = File(p.join(project.output, 'ratel_app_manifest.dart'))
          .readAsStringSync();
      final run = await project.run(p.join('bin', 'probe.dart'));
      expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
      probe = jsonDecode('${run.stdout}'.trim()) as Map<String, Object?>;
    });

    tearDownAll(() => project.dispose());

    const article = {
      'createdAt': '2024-01-02T03:04:05.000Z',
      'updatedAt': null,
      'version': 3,
      'id': 7,
      'title': 'Hi',
      'status': 'published',
      'tags': [
        {'label': 'a', 'weight': 2.0},
        {'label': 'b', 'weight': 1.0},
      ],
      'scores': {'views': 3},
      'flags': ['x', 'y'],
      'address': {'city': 'Oslo', 'zip': null, 'line': 'Oslo'},
      'link': 'https://x.dev/a',
      'big': '123456789012345678901234567890',
      'extra': {
        'k': [1],
      },
      'note': 'n',
      'history': ['draft', null],
      'tagCount': 2,
    };

    test('the generated codecs analyze with no errors or warnings', () async {
      final path = p.join(project.output, 'ratel_app_manifest.dart');
      final collection = AnalysisContextCollection(
        includedPaths: [path],
        sdkPath: DartSdk.root,
      );
      addTearDown(collection.dispose);
      final result = await collection
          .contextFor(path)
          .currentSession
          .getResolvedUnit(path) as ResolvedUnitResult;
      expect(
        result.diagnostics
            .where((diagnostic) => diagnostic.severity != Severity.info)
            .map((diagnostic) => diagnostic.message),
        isEmpty,
      );
    });

    test('registers one codec per generic instantiation', () {
      expect(manifest, contains('r.JsonCodecDefinition<i7.Page<i2.Article>>('));
      expect(manifest, contains('r.JsonCodecDefinition<i7.Page<i5.Tag>>('));
    });

    test('calls nested encoders and decoders directly', () {
      expect(
        manifest,
        contains("'tags': [for (final e1 in value.tags) _tagToJson(e1)],"),
      );
      expect(
        manifest,
        matches(
            RegExp(r"_tagFromJson\(r\.JsonValues\.object\(e\d+, 'tags'\)\)")),
      );
    });

    test('round-trips a nested DTO through its generated codecs', () {
      expect(probe['full'], article);
    });

    test('fills in defaults and leaves absent nullable fields empty', () {
      expect(probe['minimal'], {
        'createdAt': '2024-01-02T03:04:05.000Z',
        'updatedAt': null,
        'version': 1,
        'id': 7,
        'title': 'T',
        'status': 'draft',
        'tags': <Object?>[],
        'scores': {'views': 0},
        'flags': <Object?>[],
        'address': null,
        'link': null,
        'big': null,
        'extra': null,
        'note': null,
        'history': <Object?>[],
        'tagCount': 0,
      });
    });

    test('turns bad input into field-level 400 messages', () {
      expect(probe['missing'], 'Field "id" is required');
      expect(
        probe['date'],
        'Field "createdAt" must be an ISO-8601 date-time string',
      );
      expect(probe['nested'], 'Field "label" is required');
      expect(probe['enum'], 'Field "status" must be one of draft, published');
      expect(probe['list'], 'Field "tags" must be a JSON array');
    });

    test('encodes each instantiation of a generic DTO', () {
      expect(probe['page'], {
        'items': [article],
        'total': 1,
      });
      expect(probe['tagPage'], {
        'items': [
          {'label': 'a', 'weight': 1.0},
        ],
        'total': 1,
      });
      expect(probe['tagPageDecodes'], isFalse);
    });

    test('encodes DTOs inside maps and lists of a return type', () {
      expect(probe['stats'], {
        'all': [
          {'count': 3},
        ],
      });
    });

    test('encodes a body-only DTO without the members it cannot convert', () {
      expect(probe['search'], {'query': 'q', 'limit': 10});
    });
  });

  group('an app with hand-written and unusual DTOs', () {
    late ScratchProject project;
    late String manifest;
    late Map<String, Object?> probe;

    setUpAll(() async {
      project = await ScratchProject.create(
        'conversions',
        ScratchApps.conversions,
        packages: {'remote_dtos': ScratchApps.remoteDtos},
      );
      final result = await project.generate(write: true);
      expect(result.hasErrors, isFalse, reason: '${result.diagnostics}');
      manifest = File(p.join(project.output, 'ratel_app_manifest.dart'))
          .readAsStringSync();
      final run = await project.run(p.join('bin', 'probe.dart'));
      expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
      probe = jsonDecode('${run.stdout}'.trim()) as Map<String, Object?>;
    });

    tearDownAll(() => project.dispose());

    test('the generated codecs analyze with no errors or warnings', () async {
      final path = p.join(project.output, 'ratel_app_manifest.dart');
      final collection = AnalysisContextCollection(
        includedPaths: [path],
        sdkPath: DartSdk.root,
      );
      addTearDown(collection.dispose);
      final result = await collection
          .contextFor(path)
          .currentSession
          .getResolvedUnit(path) as ResolvedUnitResult;
      expect(
        result.diagnostics
            .where((diagnostic) => diagnostic.severity != Severity.info)
            .map((diagnostic) => diagnostic.message),
        isEmpty,
      );
    });

    test('treats a blank form value as a missing one', () {
      expect(probe['form'], {
        'name': 'Ada',
        'age': null,
        'newsletter': true,
        'grade': 'low',
        'grades': ['low'],
        'since': null,
        'token': 't',
        'rank': null,
      });
      expect(probe['blankRequired'], containsPair('name', ''));
    });

    test('uses the constructor default for a missing or null key', () {
      expect(probe['defaults'], {
        'name': 'Ada',
        'age': null,
        'newsletter': false,
        'grade': 'low',
        'grades': ['high'],
        'since': null,
        'token': 't',
        'rank': null,
      });
    });

    test('encodes an enum by the name it decodes from', () {
      expect(manifest, contains('EnumName('));
      expect(probe['grade'], containsPair('grade', 'high'));
      expect(probe['wrongGrade'], 'Field "grade" must be one of low, high');
    });

    test('answers 400 for a late field the JSON leaves out', () {
      expect(manifest, contains("value.token = r.JsonValues.string("));
      expect(probe['missingLate'], 'Field "token" is required');
    });

    test('builds a concrete interface class', () {
      expect(probe['money'], {'amount': 3});
    });

    test('calls the toJson and fromJson a class declares', () {
      expect(manifest, matches(RegExp(r'i\d+\.User\.fromJson\(json\)')));
      expect(manifest, contains('=> value.toJson();'));
      expect(probe['user'], {'first_name': 'Ada'});
      expect(probe['raw'], {'first_name': 'Ada'});
      expect(probe['account'], {'account': 'x'});
    });

    test('round-trips a recursive DTO', () {
      expect(probe['node'], {
        'name': 'a',
        'children': [
          {'name': 'b', 'children': <Object?>[], 'parent': null},
        ],
        'parent': null,
      });
    });

    test('gives same-named classes and other packages their own codecs', () {
      expect(manifest, contains('_labelToJson('));
      expect(manifest, contains('_labelToJson2('));
      expect(manifest, contains('package:remote_dtos/src/remote_point.dart'));
      expect(probe['pair'], {
        'label': {'text': 't'},
        'legacyLabel': {'code': 1},
        'point': {'x': 1, 'y': 2},
      });
    });
  });
}
