import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

String generatedLibraryUri(ClassElement element, BuildStep buildStep) {
  final uri = element.library.uri;
  if (uri.isScheme('package')) return _swapExtension(uri.toString());
  if (uri.isScheme('asset')) {
    final id = AssetId.resolve(uri);
    final from = p.url.dirname(buildStep.inputId.path);
    return _swapExtension(p.url.relative(id.path, from: from));
  }
  throw InvalidGenerationSourceError(
    'Cannot import generated code for ${element.displayName}, '
    'declared in $uri.',
    element: element,
  );
}

String _swapExtension(String uri) =>
    '${uri.substring(0, uri.length - '.dart'.length)}.ratel.dart';
