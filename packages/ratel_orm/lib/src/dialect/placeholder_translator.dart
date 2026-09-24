String translatePlaceholders(String sql, String Function(String name) render) {
  final out = StringBuffer();
  var i = 0;
  while (i < sql.length) {
    final char = sql[i];

    if (char == "'" || char == '"') {
      i = _copyStringLiteral(sql, i, out);
      continue;
    }
    if (char == '-' && _peek(sql, i + 1) == '-') {
      i = _copyLineComment(sql, i, out);
      continue;
    }
    if (char == '/' && _peek(sql, i + 1) == '*') {
      i = _copyBlockComment(sql, i, out);
      continue;
    }
    if (char == ':' && _peek(sql, i + 1) == ':') {
      out.write('::');
      i += 2;
      continue;
    }
    if (char == '@') {
      var j = i + 1;
      while (j < sql.length && _isNameChar(sql[j])) {
        j++;
      }
      if (j > i + 1) {
        out.write(render(sql.substring(i + 1, j)));
        i = j;
        continue;
      }
    }
    out.write(char);
    i++;
  }
  return out.toString();
}

int _copyStringLiteral(String sql, int start, StringBuffer out) {
  final quote = sql[start];
  out.write(quote);
  var i = start + 1;
  while (i < sql.length) {
    final char = sql[i];
    out.write(char);
    if (char == quote) {
      if (_peek(sql, i + 1) == quote) {
        out.write(quote);
        i += 2;
        continue;
      }
      return i + 1;
    }
    i++;
  }
  return i;
}

int _copyLineComment(String sql, int start, StringBuffer out) {
  var i = start;
  while (i < sql.length && sql[i] != '\n') {
    out.write(sql[i]);
    i++;
  }
  return i;
}

int _copyBlockComment(String sql, int start, StringBuffer out) {
  out.write('/*');
  var i = start + 2;
  while (i < sql.length && !(sql[i] == '*' && _peek(sql, i + 1) == '/')) {
    out.write(sql[i]);
    i++;
  }
  if (i < sql.length) {
    out.write('*/');
    return i + 2;
  }
  return i;
}

String? _peek(String sql, int index) => index < sql.length ? sql[index] : null;

bool _isNameChar(String char) {
  final code = char.codeUnitAt(0);
  final isDigit = code >= 48 && code <= 57;
  final isUpper = code >= 65 && code <= 90;
  final isLower = code >= 97 && code <= 122;
  return isDigit || isUpper || isLower || char == '_';
}
