import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../diagnostics/diagnostic_codes.dart';
import '../diagnostics/element_diagnostics.dart';
import '../diagnostics/ratel_diagnostic.dart';
import '../model/scanned_entity.dart';
import 'entity_scanner.dart';
import 'orm_annotations.dart';

abstract final class RepositoryChecks {
  static void check(
    List<LibraryElement> libraries,
    List<ScannedEntity> entities,
    List<RatelDiagnostic> diagnostics,
  ) {
    final scanned = {for (final entity in entities) entity.element: entity};
    final annotated = EntityScanner.annotatedIn(libraries).toSet();
    final project = libraries.toSet();
    for (final library in libraries) {
      for (final element in library.classes) {
        final repository = OrmAnnotations.repositoryOf(element);
        if (repository == null || repository.typeArguments.length != 2) {
          continue;
        }
        final problem = _problem(
          library,
          element.name ?? '',
          repository.typeArguments.first,
          repository.typeArguments.last,
          scanned,
          annotated,
          project,
        );
        if (problem != null) {
          diagnostics
              .add(ElementDiagnostics.at(element, problem.$1, problem.$2));
        }
      }
    }
  }

  static (String, String)? _problem(
    LibraryElement library,
    String name,
    DartType stored,
    DartType key,
    Map<ClassElement, ScannedEntity> scanned,
    Set<ClassElement> annotated,
    Set<LibraryElement> project,
  ) {
    if (stored is! InterfaceType) return null;
    final display = stored.getDisplayString();
    final element = stored.element;
    if (!OrmAnnotations.has(element, OrmAnnotations.entity)) {
      return (
        DiagnosticCodes.repositoryNotEntity,
        '$name stores $display, which is not an @Entity, so Ratel has no '
            'mapper for its rows. ${_advice(element, project)}',
      );
    }
    final entity = scanned[element];
    if (entity == null) {
      if (annotated.contains(element)) return null;
      return (
        DiagnosticCodes.repositoryNotEntity,
        '$name stores $display, an @Entity declared outside this project. '
            'Ratel generates entity mappers only for the classes in lib/ and '
            'next to the entrypoint, so move ${element.name} into this project.',
      );
    }
    if (key is! InterfaceType) return null;
    final typeSystem = library.typeSystem;
    final id = entity.id;
    final expected = typeSystem.promoteToNonNull(id.type);
    if (typeSystem.isSubtypeOf(key, expected) &&
        typeSystem.isSubtypeOf(expected, key)) {
      return null;
    }
    final expectedDisplay = expected.getDisplayString();
    return (
      DiagnosticCodes.repositoryIdMismatch,
      '$name declares the id type ${key.getDisplayString()}, but the @Id() '
          'field ${entity.name}.${id.field} has type '
          '${id.type.getDisplayString()}. Declare it as '
          'RatelRepository<$display, $expectedDisplay>.',
    );
  }

  static String _advice(InterfaceElement element, Set<LibraryElement> project) {
    final concrete = element is ClassElement &&
        !element.isAbstract &&
        !element.isSealed &&
        element.typeParameters.isEmpty;
    if (concrete && project.contains(element.library)) {
      return 'Annotate ${element.name} with @Entity() and mark its primary '
          'key with @Id().';
    }
    return 'Store a concrete @Entity class of this project instead.';
  }
}
