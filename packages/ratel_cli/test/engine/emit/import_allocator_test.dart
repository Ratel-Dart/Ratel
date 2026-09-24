import 'package:ratel_cli/src/engine/emit/import_allocator.dart';
import 'package:ratel_cli/src/engine/emit/import_uris.dart';
import 'package:ratel_cli/src/project/project_runtimes.dart';
import 'package:test/test.dart';

void main() {
  const framework = ProjectRuntimes(framework: true, orm: false);
  const orm = ProjectRuntimes(framework: false, orm: true);
  const both = ProjectRuntimes(framework: true, orm: true);

  test('imports each present runtime under its fixed prefix', () {
    expect(ImportAllocator.runtimeDirectives(framework), [
      "import 'package:ratel/runtime.dart' as r;",
    ]);
    expect(ImportAllocator.runtimeDirectives(orm), [
      "import 'package:ratel_orm/runtime.dart' as o;",
    ]);
    expect(ImportAllocator.runtimeDirectives(both), [
      "import 'package:ratel/runtime.dart' as r;",
      "import 'package:ratel_orm/runtime.dart' as o;",
    ]);
  });

  test('groups the runtimes with the libraries it allocated', () {
    final imports = ImportAllocator(ImportUris('/out'), runtimes: orm);
    expect(imports.prefixFor(Uri.parse('package:app/user.dart')), 'i1');
    expect(imports.prefixFor(Uri.parse('dart:typed_data')), 'i2');
    expect(imports.prefixFor(Uri.parse('dart:core')), isNull);
    expect(imports.directives(extra: {'other.dart': null}), [
      "import 'dart:typed_data' as i2;",
      "import 'package:app/user.dart' as i1;\n"
          "import 'package:ratel_orm/runtime.dart' as o;",
      "import 'other.dart';",
    ]);
  });

  test('imports no runtime the project lacks', () {
    final imports = ImportAllocator(ImportUris('/out'), runtimes: framework);
    expect(imports.directives(), ["import 'package:ratel/runtime.dart' as r;"]);
  });
}
