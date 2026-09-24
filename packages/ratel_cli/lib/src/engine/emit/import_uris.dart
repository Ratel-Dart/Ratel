import 'package:path/path.dart' as p;

final class ImportUris {
  ImportUris(this.outputDirectory);

  final String outputDirectory;

  static const _publicSdkLibraries = {'dart:_http': 'dart:io'};

  String resolve(Uri library) {
    final text = library.toString();
    final public = _publicSdkLibraries[text];
    if (public != null) return public;
    if (library.isScheme('dart')) return text;
    if (library.isScheme('package')) {
      final segments = library.pathSegments;
      if (segments.isNotEmpty && segments.first == 'ratel') {
        return 'package:ratel/ratel.dart';
      }
      return text;
    }
    return relativeFile(library.toFilePath());
  }

  String relativeFile(String path) => p.url.joinAll(
        p.split(p.relative(path, from: outputDirectory)),
      );
}
