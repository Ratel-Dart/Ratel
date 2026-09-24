import 'package:ratel_cli/src/engine/diagnostics/diagnostic_codes.dart';
import 'package:ratel_cli/src/engine/diagnostics/ratel_diagnostic.dart';
import 'package:ratel_cli/src/engine/generation_result.dart';
import 'package:ratel_cli/src/engine/model/scanned_dto.dart';
import 'package:test/test.dart';

import '../../support/scratch_apps.dart';
import '../../support/scratch_project.dart';

void main() {
  group('a newsroom app', () {
    late ScratchProject project;
    late GenerationResult result;

    setUpAll(() async {
      project = await ScratchProject.create('newsroom', ScratchApps.newsroom);
      result = await project.generate();
    });

    tearDownAll(() => project.dispose());

    ScannedDto dto(String display) => result.app.dtos
        .singleWhere((dto) => dto.type.getDisplayString() == display);

    test('reports nothing', () {
      expect(result.diagnostics, isEmpty);
    });

    test('finds the DTOs that route signatures reach', () {
      expect(
        result.app.dtos.map((dto) => dto.type.getDisplayString()),
        unorderedEquals([
          'Article',
          'Tag',
          'Address',
          'Page<Article>',
          'Page<Tag>',
          'Summary',
          'Search',
        ]),
      );
    });

    test('decodes body types and encodes returned types', () {
      expect(dto('Article').decodes, isTrue);
      expect(dto('Article').encodes, isTrue);
      expect(dto('Tag').decodes, isTrue);
      expect(dto('Address').decodes, isTrue);
      expect(dto('Page<Tag>').encodes, isTrue);
      expect(dto('Page<Tag>').decodes, isFalse);
      expect(dto('Summary').encodes, isTrue);
      expect(dto('Summary').decoding, isNull);
      expect(dto('Search').decodes, isTrue);
      expect(dto('Search').encodes, isFalse);
    });

    test('encodes fields and getters from the base class down', () {
      expect(dto('Article').properties.map((property) => property.name), [
        'createdAt',
        'updatedAt',
        'version',
        'id',
        'title',
        'status',
        'tags',
        'scores',
        'flags',
        'address',
        'link',
        'big',
        'extra',
        'note',
        'history',
        'tagCount',
      ]);
      expect(
        dto('Address').properties.map((property) => property.name),
        ['city', 'zip', 'line'],
      );
    });

    test('leaves out what a body-only DTO cannot encode', () {
      expect(
        dto('Search').properties.map((property) => property.name),
        ['query', 'limit'],
      );
    });

    test('substitutes the type arguments of a generic DTO', () {
      final items = dto('Page<Tag>')
          .properties
          .singleWhere((property) => property.name == 'items');
      expect(items.type.getDisplayString(), 'List<Tag>');
    });

    test('plans decoding through the constructor, then the setters', () {
      final plan = dto('Article').decoding!;
      expect(plan.arguments.map((argument) => argument.property), [
        'id',
        'title',
        'createdAt',
        'updatedAt',
        'status',
        'tags',
        'scores',
        'flags',
        'address',
        'link',
        'big',
        'extra',
      ]);
      expect(
        plan.assignments.map((field) => field.name),
        ['version', 'note', 'history'],
      );
    });
  });

  group('a faulty app', () {
    late ScratchProject project;
    late GenerationResult result;

    setUpAll(() async {
      project = await ScratchProject.create('faulty', ScratchApps.faulty);
      result = await project.generate();
    });

    tearDownAll(() => project.dispose());

    List<RatelDiagnostic> all(String code) => [
          for (final diagnostic in result.diagnostics)
            if (diagnostic.code == code) diagnostic,
        ];

    RatelDiagnostic about(String code, String text) => all(code)
        .singleWhere((diagnostic) => diagnostic.message.contains(text));

    test('writes nothing', () {
      expect(result.hasErrors, isTrue);
      expect(result.files, isEmpty);
    });

    test('rejects a body that is not a class', () {
      final body = about(DiagnosticCodes.bodyNotClass, 'FaultyController.map');
      expect(body.path, endsWith('faulty_controller.dart'));
      expect(body.message, contains('Map<String, dynamic>'));
    });

    test('names the path to a property of an unsupported type', () {
      expect(
        about(DiagnosticCodes.dtoUnsupportedType, 'Order.window').message,
        startsWith(
          'FaultyController.order -> Order.window has type (int, int)?, '
          'which Ratel cannot convert to JSON.',
        ),
      );
      final meta = about(DiagnosticCodes.dtoUnsupportedType, 'Line.meta');
      expect(
        meta.message,
        startsWith('FaultyController.order -> Order.lines -> Line.meta has '
            'type void Function()?'),
      );
      expect(meta.path, endsWith('line.dart'));
    });

    test('rejects abstract classes at the root and inside a DTO', () {
      expect(
        about(DiagnosticCodes.dtoAbstract, 'FaultyController.shape uses')
            .message,
        contains('an abstract class'),
      );
      expect(
        about(DiagnosticCodes.dtoAbstract, 'Order.shape').message,
        startsWith('FaultyController.order -> Order.shape uses Shape'),
      );
    });

    test('rejects bodies it cannot build', () {
      final frozen = about(DiagnosticCodes.dtoNotConstructible, 'Frozen');
      expect(frozen.message, contains('no public unnamed constructor'));
      expect(frozen.path, endsWith('frozen.dart'));
      expect(
        about(DiagnosticCodes.dtoNotConstructible, 'Mismatch').message,
        contains('unknown'),
      );
      expect(
        about(DiagnosticCodes.dtoNotConstructible, 'Timed').message,
        contains('make the field nullable or required'),
      );
    });

    test('rejects a private payload type', () {
      expect(
        about(DiagnosticCodes.privateClass, 'FaultyController.hidden').message,
        contains('_Hidden'),
      );
    });

    test('rejects a bare type parameter', () {
      expect(
        about(DiagnosticCodes.dtoUnsupportedType, 'Box.value').message,
        startsWith('FaultyController.box -> Box.value has type T'),
      );
    });

    test('checks every getter of a returned DTO', () {
      expect(
        about(DiagnosticCodes.dtoUnsupportedType, 'Report.feed').message,
        startsWith('FaultyController.report -> Report.feed has type '
            'Stream<int>'),
      );
    });

    test('skips what a body-only DTO cannot encode without an error', () {
      expect(
        result.diagnostics.where(
          (diagnostic) => diagnostic.message.contains('Lenient'),
        ),
        isEmpty,
      );
    });

    test('stops at a generic DTO whose type arguments grow', () {
      final growth = [
        for (final diagnostic in all(DiagnosticCodes.dtoUnsupportedType))
          if (diagnostic.message.contains('grow')) diagnostic,
      ];
      expect(growth, hasLength(1));
      expect(
        growth.single.message,
        startsWith('FaultyController.nest -> Nest.next nests Nest inside '
            'itself'),
      );
      expect(growth.single.path, endsWith('nest.dart'));
    });

    test('reports a bad property once when a DTO is both body and result', () {
      final window = [
        for (final diagnostic in result.diagnostics)
          if (diagnostic.path.endsWith('window.dart')) diagnostic,
      ];
      expect(
        window.map((diagnostic) => diagnostic.message.split(' has type ')[0]),
        unorderedEquals([
          'FaultyController.window -> Window.range',
          'FaultyController.window -> Window.feed',
        ]),
      );
      expect(
        window.map((diagnostic) => (diagnostic.line, diagnostic.column)),
        unorderedEquals([(1, 31), (1, 57)]),
      );
    });

    test('explains the removed @Json annotation', () {
      final legacy = result.diagnostics
          .singleWhere((diagnostic) => diagnostic.path.endsWith('legacy.dart'));
      expect(legacy.message, contains('@Json was removed'));
    });
  });

  group('an app with hand-written and unusual DTOs', () {
    late ScratchProject project;
    late GenerationResult result;

    setUpAll(() async {
      project = await ScratchProject.create(
        'conversions',
        ScratchApps.conversions,
        packages: {'remote_dtos': ScratchApps.remoteDtos},
      );
      result = await project.generate();
    });

    tearDownAll(() => project.dispose());

    ScannedDto dto(String display) => result.app.dtos
        .singleWhere((dto) => dto.type.getDisplayString() == display);

    test('reports nothing', () {
      expect(result.diagnostics, isEmpty);
    });

    test('defers to the toJson and fromJson a class declares', () {
      for (final name in ['User', 'Account']) {
        expect(dto(name).usesToJson, isTrue, reason: name);
        expect(dto(name).usesFromJson, isTrue, reason: name);
        expect(dto(name).decoding, isNull, reason: name);
        expect(dto(name).properties, isEmpty, reason: name);
      }
      expect(dto('Money').usesToJson, isFalse);
      expect(dto('Money').usesFromJson, isFalse);
    });

    test('builds a concrete interface class', () {
      expect(dto('Money').decoding, isNotNull);
    });

    test('always assigns a late field that starts without a value', () {
      final assignments = dto('Signup').decoding!.assignments;
      expect(assignments.map((field) => field.name), ['token', 'rank']);
      expect(assignments.every((field) => field.startsUnset), isTrue);
    });

    test('keeps same-named classes from different libraries apart', () {
      final labels = result.app.dtos
          .where((dto) => dto.type.getDisplayString() == 'Label')
          .map((dto) => dto.type.element.library.uri.path);
      expect(
        labels,
        unorderedEquals(
            ['conversions/models/label.dart', 'conversions/legacy/label.dart']),
      );
    });

    test('reaches a DTO from another package', () {
      expect(dto('RemotePoint').decodes, isTrue);
      expect(
        dto('RemotePoint').type.element.library.uri.toString(),
        'package:remote_dtos/src/remote_point.dart',
      );
    });

    test('walks a recursive DTO once', () {
      expect(
        result.app.dtos.where((dto) => dto.type.getDisplayString() == 'Node'),
        hasLength(1),
      );
    });
  });
}
