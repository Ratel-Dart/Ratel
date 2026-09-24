import 'package:analyzer/dart/constant/value.dart';
import 'package:ratel_cli/src/engine/emit/constant_emitter.dart';
import 'package:test/test.dart';

import '../../support/scratch_apps.dart';
import '../../support/scratch_project.dart';

void main() {
  late ScratchProject project;
  late Map<String, DartObject> defaults;

  setUpAll(() async {
    project = await ScratchProject.create('samples', ScratchApps.samples);
    final library = await project.library('lib/samples.dart');
    final constructor = library.getClass('Defaults')!.unnamedConstructor!;
    defaults = {
      for (final parameter in constructor.formalParameters)
        parameter.name ?? '': parameter.computeConstantValue()!,
    };
  });

  tearDownAll(() => project.dispose());

  String? emit(String name) =>
      ConstantEmitter.emit(defaults[name]!, (type) => 'p.$type');

  test('writes literals', () {
    expect(emit('a'), '1');
    expect(emit('b'), '1.5');
    expect(emit('c'), r"'it\'s \$x'");
    expect(emit('d'), 'true');
    expect(emit('e'), 'null');
    expect(emit('k'), 'double.infinity');
    expect(emit('l'), '3.0');
  });

  test('writes enum values through the type name', () {
    expect(emit('f'), 'p.Tone.loud');
  });

  test('writes const collections with their type arguments', () {
    expect(emit('g'), 'const <p.Tone>[p.Tone.soft]');
    expect(emit('h'), "const <p.String, p.List<int>>{'k': <p.int>[1]}");
    expect(emit('i'), 'const <p.int>{2, 3}');
  });

  test('refuses instances of other classes', () {
    expect(emit('j'), isNull);
    expect(ConstantEmitter.canEmit(defaults['j']!), isFalse);
    expect(ConstantEmitter.canEmit(defaults['h']!), isTrue);
  });
}
