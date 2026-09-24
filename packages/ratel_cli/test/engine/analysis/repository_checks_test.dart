import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/diagnostics/diagnostic_codes.dart';
import 'package:ratel_cli/src/engine/diagnostics/ratel_diagnostic.dart';
import 'package:ratel_cli/src/engine/generation_result.dart';
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

  RatelDiagnostic single(String code, [String? file]) =>
      faulty.diagnostics.singleWhere(
        (diagnostic) =>
            diagnostic.code == code &&
            (file == null || p.basename(diagnostic.path) == file),
      );

  test('accepts repositories of entities with their id type', () {
    expect(
      mapped.diagnostics.where(
        (diagnostic) => diagnostic.code.startsWith('ratel_repository'),
      ),
      isEmpty,
    );
  });

  test('reports a repository of a class that is not an entity', () {
    final found = single(
      DiagnosticCodes.repositoryNotEntity,
      'plain_repository.dart',
    );
    expect(found.line, 5);
    expect(
      found.message,
      allOf([
        contains('PlainRepository stores Plain'),
        contains('not an @Entity'),
        contains('Annotate Plain with @Entity()'),
      ]),
    );
  });

  test('does not ask to annotate an SDK or abstract class', () {
    final sdk = single(
      DiagnosticCodes.repositoryNotEntity,
      'date_repository.dart',
    );
    expect(
      sdk.message,
      allOf([
        contains('DateRepository stores DateTime, which is not an @Entity'),
        contains('Store a concrete @Entity class of this project instead.'),
        isNot(contains('Annotate')),
      ]),
    );
    final abstract = single(
      DiagnosticCodes.repositoryNotEntity,
      'base_repository.dart',
    );
    expect(
      abstract.message,
      allOf([
        contains('BaseRepository stores OrphanBase'),
        contains('Store a concrete @Entity class of this project instead.'),
      ]),
    );
  });

  test('reports a repository whose id type differs from the @Id field', () {
    final found = single(DiagnosticCodes.repositoryIdMismatch);
    expect(p.basename(found.path), 'keeper_repository.dart');
    expect(
      found.message,
      allOf([
        contains('KeeperRepository declares the id type String'),
        contains('Keeper.id has type int'),
        contains('RatelRepository<Keeper, int>'),
      ]),
    );
  });

  test('explains the old single type argument of RatelRepository', () {
    final found = single('wrong_number_of_type_arguments');
    expect(p.basename(found.path), 'legacy_repository.dart');
    expect(
      found.message,
      contains('RatelRepository now takes <T, ID>, e.g. '
          'RatelRepository<User, int>; rows are mapped from @Entity.'),
    );
  });
}
