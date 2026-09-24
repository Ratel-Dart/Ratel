import 'package:ratel_cli/src/project/project_runtimes.dart';
import 'package:ratel_cli/src/project/runtime_compatibility.dart';
import 'package:test/test.dart';

import '../support/scratch_entities.dart';
import '../support/scratch_project.dart';

void main() {
  Future<({ProjectRuntimes? runtimes, String? error})> check({
    Map<String, String>? orm,
    bool framework = true,
  }) async {
    final project = await ScratchProject.create(
      'detected',
      const {'lib/detected.dart': 'class Detected {}\n'},
      packages: {if (orm != null) 'ratel_orm': orm},
      framework: framework,
    );
    addTearDown(project.dispose);
    return RuntimeCompatibility.check(project.analyzer);
  }

  test('detects a framework-only project', () async {
    final (:runtimes, :error) = await check();
    expect(error, isNull);
    expect(runtimes?.framework, isTrue);
    expect(runtimes?.orm, isFalse);
  });

  test('detects an ORM-only project', () async {
    final (:runtimes, :error) =
        await check(orm: ScratchEntities.ormStub, framework: false);
    expect(error, isNull);
    expect(runtimes?.framework, isFalse);
    expect(runtimes?.orm, isTrue);
  });

  test('detects a project that uses both', () async {
    final (:runtimes, :error) = await check(orm: ScratchEntities.ormStub);
    expect(error, isNull);
    expect(runtimes?.framework, isTrue);
    expect(runtimes?.orm, isTrue);
  });

  test('ignores a ratel_orm without a runtime next to ratel', () async {
    final (:runtimes, :error) = await check(orm: ScratchEntities.legacyOrmStub);
    expect(error, isNull);
    expect(runtimes?.framework, isTrue);
    expect(runtimes?.orm, isFalse);
  });

  test('asks to upgrade a ratel_orm without a runtime on its own', () async {
    final (:runtimes, :error) =
        await check(orm: ScratchEntities.legacyOrmStub, framework: false);
    expect(runtimes, isNull);
    expect(error, contains('dart pub upgrade ratel_orm'));
  });

  test('refuses a ratel_orm with another contract', () async {
    final (:runtimes, :error) =
        await check(orm: ScratchEntities.futureOrmStub, framework: false);
    expect(runtimes, isNull);
    expect(
      error,
      allOf([
        contains('ratel_orm runtime contract 1'),
        contains('a ratel_orm with contract 2'),
      ]),
    );
  });

  test('names both packages when the project uses neither', () async {
    final (:runtimes, :error) = await check(framework: false);
    expect(runtimes, isNull);
    expect(
      error,
      'This project depends on neither ratel nor ratel_orm. Run: dart pub '
      'add ratel (HTTP) or dart pub add ratel_orm (database).',
    );
  });
}
