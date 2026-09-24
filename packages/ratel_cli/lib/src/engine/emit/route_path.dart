abstract final class RoutePath {
  static String join(String prefix, String path) {
    if (prefix.isEmpty) return path;
    var base =
        prefix.endsWith('/') ? prefix.substring(0, prefix.length - 1) : prefix;
    if (!base.startsWith('/')) base = '/$base';
    final tail = path.startsWith('/') ? path : '/$path';
    var joined = '$base$tail';
    if (joined.length > 1 && joined.endsWith('/')) {
      joined = joined.substring(0, joined.length - 1);
    }
    return joined;
  }
}
