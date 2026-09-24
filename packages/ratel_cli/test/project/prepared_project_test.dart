import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:ratel_cli/src/engine/model/generation_mode.dart';
import 'package:ratel_cli/src/project/prepared_project.dart';
import 'package:ratel_cli/src/project/ratel_project.dart';
import 'package:test/test.dart';

import '../support/scratch_entities.dart';
import '../support/scratch_project.dart';

void main() {
  test('keeps refusing changes after a failed runtime check until one passes',
      () async {
    final scratch = await ScratchProject.create(
      'reopened',
      const {'bin/main.dart': 'void main() {}\n'},
      packages: {'ratel_orm': ScratchEntities.ormStub},
      framework: false,
    );
    addTearDown(scratch.dispose);
    final project = RatelProject.locate(Directory(scratch.root))!;
    final main = File(p.join(scratch.root, 'bin', 'main.dart'));
    final prepared = (await PreparedProject.open(project, main))!;
    addTearDown(prepared.dispose);
    expect(prepared.incompatibility, isNull);
    expect(prepared.runtimes.orm, isTrue);

    final runtime = File(
      p.join(scratch.root, 'packages', 'ratel_orm', 'lib', 'runtime.dart'),
    );
    final compatible = runtime.readAsStringSync();
    runtime.writeAsStringSync(
      compatible.replaceFirst('contract = 1', 'contract = 2'),
    );
    final refused = await prepared.reopen();
    expect(refused, contains('a ratel_orm with contract 2'));

    main.writeAsStringSync("void main() {\n  print('edited');\n}\n");
    expect(await prepared.changed({main.path}), refused);
    expect(prepared.incompatibility, refused);

    runtime.writeAsStringSync(compatible);
    expect(await prepared.reopen(), isNull);
    expect(await prepared.changed({main.path}), isNull);
    final result = await prepared.generation(GenerationMode.dev).run();
    expect(result.hasErrors, isFalse);
  });
}
