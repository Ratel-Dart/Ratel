import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:ratel_cli/src/engine/analysis/json_types.dart';
import 'package:ratel_cli/src/engine/model/json_kind.dart';
import 'package:test/test.dart';

import '../../support/scratch_apps.dart';
import '../../support/scratch_project.dart';

void main() {
  late ScratchProject project;
  late ClassElement kinds;

  setUpAll(() async {
    project = await ScratchProject.create('samples', ScratchApps.samples);
    kinds = (await project.library('lib/samples.dart')).getClass('Kinds')!;
  });

  tearDownAll(() => project.dispose());

  DartType field(String name) => kinds.getField(name)!.type;

  test('classifies leaves, collections and DTOs', () {
    const expected = {
      'integer': JsonKind.integer,
      'real': JsonKind.real,
      'number': JsonKind.number,
      'string': JsonKind.string,
      'boolean': JsonKind.boolean,
      'dateTime': JsonKind.dateTime,
      'uri': JsonKind.uri,
      'bigInt': JsonKind.bigInt,
      'tone': JsonKind.enumeration,
      'opaque': JsonKind.opaque,
      'loose': JsonKind.opaque,
      'list': JsonKind.list,
      'set': JsonKind.set,
      'iterable': JsonKind.iterable,
      'map': JsonKind.map,
      'dto': JsonKind.dto,
      'shape': JsonKind.dto,
      'tags': JsonKind.list,
    };
    expect(
      {for (final name in expected.keys) name: JsonTypes.kind(field(name))},
      expected,
    );
  });

  test('refuses types JSON cannot carry', () {
    for (final name in [
      'intKeys',
      'record',
      'function',
      'future',
      'futureOr',
      'duration',
      'response',
      'id',
    ]) {
      expect(JsonTypes.kind(field(name)), JsonKind.unsupported, reason: name);
    }
  });

  test('finds the DTOs inside collections', () {
    expect(
      JsonTypes.dtosIn(field('map'))!.map((type) => type.toString()),
      ['Point'],
    );
    expect(
      JsonTypes.dtosIn(field('nested'))!.map((type) => type.toString()),
      ['Holder<Point?>'],
    );
    expect(JsonTypes.dtosIn(field('list')), isEmpty);
    expect(JsonTypes.dtosIn(field('record')), isNull);
  });

  test('passes JSON-native values through unchanged', () {
    expect(JsonTypes.passesThrough(field('list')), isTrue);
    expect(JsonTypes.passesThrough(field('opaque')), isTrue);
    expect(JsonTypes.passesThrough(field('set')), isFalse);
    expect(JsonTypes.passesThrough(field('dateTime')), isFalse);
  });

  test('spots private types behind names and aliases', () {
    expect(JsonTypes.isPublic(field('tags')), isTrue);
    expect(JsonTypes.isPublic(field('secret')), isFalse);
    expect(JsonTypes.isPublic(field('mood')), isFalse);
  });

  test('keys each instantiation apart and sees through aliases', () {
    final holder = JsonTypes.dtosIn(field('nested'))!.single;
    final point = holder.typeArguments.single;
    expect(JsonTypes.key(point), endsWith('#Point?'));
    expect(JsonTypes.key(holder), endsWith('#Holder<${JsonTypes.key(point)}>'));
    expect(JsonTypes.key(field('tags')), 'dart:core#List<dart:core#String>');
    expect(JsonTypes.key(field('opaque')), 'dart:core#Object?');
    expect(JsonTypes.key(field('loose')), 'dynamic');
  });
}
