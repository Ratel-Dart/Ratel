abstract final class RoutePath {
  static List<String> split(String path) {
    var normalized = path;
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized.isEmpty) return const [];
    return normalized.split('/');
  }

  static String normalize(String path) => '/${split(path).join('/')}';
}
