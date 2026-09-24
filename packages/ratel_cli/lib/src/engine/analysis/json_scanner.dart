import 'package:analyzer/dart/element/element.dart';

import '../diagnostics/diagnostic_codes.dart';
import '../diagnostics/element_diagnostics.dart';
import '../diagnostics/ratel_diagnostic.dart';
import '../model/scanned_field.dart';
import '../model/scanned_json_class.dart';
import 'element_queries.dart';
import 'ratel_annotations.dart';

abstract final class JsonScanner {
  static List<ScannedJsonClass> scan(
    LibraryElement library,
    List<RatelDiagnostic> diagnostics,
  ) {
    final classes = <ScannedJsonClass>[];
    for (final element in library.classes) {
      if (!RatelAnnotations.has(element, 'Json')) continue;
      if (element.isPrivate) {
        diagnostics.add(ElementDiagnostics.at(
          element,
          DiagnosticCodes.privateClass,
          'The @Json class ${element.name} must be public: its generated '
          'codec lives in another library. Rename it without the leading '
          'underscore.',
        ));
        continue;
      }
      classes.add(ScannedJsonClass(
        element: element,
        encoded: [
          for (final field in ElementQueries.serializableFields(element))
            field.name ?? '',
          for (final getter in ElementQueries.serializableGetters(element))
            getter.name ?? '',
        ],
        decoded: [
          for (final field in ElementQueries.serializableFields(element))
            if (!field.isFinal)
              ScannedField(name: field.name ?? '', type: field.type),
        ],
        isConstructible: ElementQueries.canConstruct(element),
      ));
    }
    return classes;
  }
}
