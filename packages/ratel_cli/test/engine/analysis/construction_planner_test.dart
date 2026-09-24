import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:ratel_cli/src/engine/analysis/construction_planner.dart';
import 'package:ratel_cli/src/engine/model/construction_plan.dart';
import 'package:test/test.dart';

import '../../support/scratch_apps.dart';
import '../../support/scratch_project.dart';

void main() {
  late ScratchProject project;
  late LibraryElement library;

  setUpAll(() async {
    project = await ScratchProject.create('samples', ScratchApps.samples);
    library = await project.library('lib/samples.dart');
  });

  tearDownAll(() => project.dispose());

  InterfaceType type(String name) => library.getClass(name)!.thisType;

  ConstructionPlan plan(InterfaceType type) {
    final (:plan, :problem) = ConstructionPlanner.plan(type);
    expect(problem, isNull);
    return plan!;
  }

  String? problem(String name) => ConstructionPlanner.plan(type(name)).problem;

  test('maps the declaring parameters of a primary constructor', () {
    final arguments = plan(type('Point')).arguments;
    expect(arguments.map((argument) => argument.property), ['x', 'y']);
    expect(arguments.every((argument) => !argument.isNamed), isTrue);
    expect(arguments.every((argument) => argument.isRequired), isTrue);
  });

  test('follows super parameters and inherits their defaults', () {
    final arguments = plan(type('Derived')).arguments;
    expect(
      arguments.map((argument) => argument.property),
      ['id', 'tag', 'extra'],
    );
    expect(arguments[0].isRequired, isTrue);
    expect(arguments[1].defaultValue?.toStringValue(), 'a');
    expect(arguments[2].defaultValue?.toIntValue(), 2);
  });

  test('matches the plain parameters of a factory by name', () {
    final argument = plan(type('Made')).arguments.single;
    expect(argument.property, 'a');
    expect(argument.isNamed, isTrue);
    expect(argument.defaultValue?.toIntValue(), 1);
  });

  test('needs a public unnamed constructor on a concrete class', () {
    expect(problem('Named'), contains('no public unnamed constructor'));
    expect(problem('Shape'), contains('abstract'));
  });

  test('refuses a required parameter that matches no property', () {
    expect(problem('Needy'), contains('secret'));
  });

  test('keeps a skipped positional parameter that a later one needs', () {
    final arguments = plan(type('Gap')).arguments;
    expect(arguments.map((argument) => argument.property), ['a', null, 'b']);
    expect(arguments[1].defaultValue?.toIntValue(), 5);
  });

  test('drops optional parameters that match nothing', () {
    expect(
      plan(type('Tail')).arguments.map((argument) => argument.property),
      ['a'],
    );
  });

  test('substitutes the type arguments of a generic class', () {
    final holder = library.getClass('Holder')!.instantiate(
      typeArguments: [library.typeProvider.intType],
      nullabilitySuffix: NullabilitySuffix.none,
    );
    expect(
      plan(holder).arguments.map((argument) => argument.type.toString()),
      ['int', 'List<int>'],
    );
  });

  test('assigns mutable public fields the constructor does not cover', () {
    final assignments = plan(type('Mutable')).assignments;
    expect(assignments.map((field) => field.name), ['name', 'locked']);
    expect(assignments.map((field) => field.startsUnset), [false, true]);
  });
}
