import 'dart:mirrors';

import 'package:postgres/postgres.dart';

import 'database.dart';
import '../annotations/geral_annotations.dart';

abstract class RatelRepository<T> {
  static RatelDatabase? dbConnection;
  static void configure(RatelDatabase connection) {
    dbConnection = connection;
  }

  Future<Connection> get connection async {
    if (dbConnection == null)
      throw Exception("Conexão com o banco não foi configurada.");
    return await dbConnection!.connect();
  }

  Future<dynamic> execute(String sql,
      {Map<String, dynamic>? substitutionValues}) async {
    final conn = await connection;
    try {
      final result =
          await conn.execute(Sql.named(sql), parameters: substitutionValues);
      if (result.length == 1) return result.first;
      return result;
    } catch (e) {
      print(e);
    }
    return [];
  }

  Future<List<T>> query(String sql,
      {Map<String, dynamic>? substitutionValues}) async {
    List<List<dynamic>> results =
        await execute(sql, substitutionValues: substitutionValues);
    if (results.isEmpty) return <T>[];
    List<String> columns = _extractColumns(sql);
    return results.map((row) {
      Map<String, dynamic> rowMap = _rowToMap(row, columns);
      return _mapRow(rowMap);
    }).toList();
  }

  List<String> _extractColumns(String sql) {
    String upperSql = sql.toUpperCase();
    int selectIndex = upperSql.indexOf("SELECT");
    int fromIndex = upperSql.indexOf("FROM");
    if (selectIndex == -1 || fromIndex == -1 || fromIndex <= selectIndex) {
      throw Exception("SQL inválido para extração de colunas.");
    }
    String columnsPart = sql.substring(selectIndex + 6, fromIndex);
    return columnsPart.split(',').map((s) {
      s = s.trim();
      var tokens = s.split(RegExp(r'\s+AS\s+', caseSensitive: false));
      return tokens.last.toLowerCase();
    }).toList();
  }

  Map<String, dynamic> _rowToMap(List<dynamic> row, List<String> columns) {
    Map<String, dynamic> map = {};
    for (int i = 0; i < columns.length && i < row.length; i++) {
      map[columns[i]] = row[i];
    }
    return map;
  }

  T _mapRow(Map<String, dynamic> row) {
    var typeMirror = reflectClass(T);
    return _generateFromRow(typeMirror, row) as T;
  }
}

dynamic _generateFromRow(ClassMirror typeMirror, Map<String, dynamic> row) {
  var instance = typeMirror.newInstance(Symbol(''), [], {});
  typeMirror.declarations.forEach((symbol, decl) {
    if (decl is VariableMirror && !decl.isStatic) {
      var colAnns = decl.metadata.where((meta) => meta.reflectee is Column);
      if (colAnns.isNotEmpty) {
        var col = colAnns.first.reflectee as Column;
        String key = col.name.isNotEmpty
            ? col.name.toLowerCase()
            : MirrorSystem.getName(symbol).toLowerCase();
        if (row.containsKey(key)) {
          instance.setField(symbol, row[key]);
        }
      }
    }
  });
  return instance.reflectee;
}
