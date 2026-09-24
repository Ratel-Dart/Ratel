import 'dart:io';

import 'package:path/path.dart' as p;

import 'project.dart';

final _bareMainPattern = RegExp(r'\bmain\s*\(\s*\)');

String writeBootstrap(RatelProject project, File entrypoint) {
  final workDir = project.workDir;
  workDir.createSync(recursive: true);

  final imports = StringBuffer();
  final calls = StringBuffer();
  var index = 0;
  for (final library in project.generatedLibraries()) {
    final alias = '_r$index';
    imports.writeln("import '${_importUri(project, library)}' as $alias;");
    calls.writeln('  $alias.\$registerRatel();');
    index++;
  }
  imports
      .writeln("import '${_importUri(project, entrypoint)}' as _entrypoint;");

  final takesArgs = !_bareMainPattern.hasMatch(entrypoint.readAsStringSync());
  final invocation =
      takesArgs ? '_entrypoint.main(args)' : '_entrypoint.main()';

  final file = File(p.join(workDir.path, 'bootstrap.dart'));
  file.writeAsStringSync(
    '$imports\n'
    'Future<void> main(List<String> args) async {\n'
    '$calls'
    '  await $invocation;\n'
    '}\n',
  );
  return file.path;
}

String _importUri(RatelProject project, File file) {
  final relative = p.relative(file.path, from: project.root.path);
  final parts = p.split(relative);
  if (parts.first == 'lib') {
    final withinLib = p.url.joinAll(parts.skip(1));
    return 'package:${project.name}/$withinLib';
  }
  return p.url.joinAll(['..', '..', ...parts]);
}
