import 'package:analyzer/dart/element/element.dart';

import '../diagnostics/diagnostic_codes.dart';
import '../diagnostics/element_diagnostics.dart';
import '../diagnostics/ratel_diagnostic.dart';
import '../model/entry_signature.dart';

abstract final class EntrySignatureReader {
  static EntrySignature? read(
    LibraryElement library,
    List<RatelDiagnostic> diagnostics,
  ) {
    for (final function in library.topLevelFunctions) {
      if (function.name != 'main') continue;
      if (function.formalParameters.length > 1) {
        diagnostics.add(ElementDiagnostics.at(
          function,
          DiagnosticCodes.unsupportedMain,
          'The entrypoint main takes more than one parameter; Ratel starts it '
          'with main() or main(List<String> args).',
        ));
        return null;
      }
      final returnType = function.returnType;
      return EntrySignature(
        takesArguments: function.formalParameters.isNotEmpty,
        returnsFuture:
            returnType.isDartAsyncFuture || returnType.isDartAsyncFutureOr,
      );
    }
    diagnostics.add(ElementDiagnostics.at(
      library,
      DiagnosticCodes.missingMain,
      'The entrypoint ${library.uri} declares no top-level main.',
    ));
    return null;
  }
}
