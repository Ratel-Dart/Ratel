import 'dart:mirrors';

import 'package:postgres/postgres.dart';

import '../annotations/geral_annotations.dart';
import 'database.dart';

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

  Future<List<T>?> execute(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    final conn = await connection;
    try {
      sql = sql.trim();
      if (sql.endsWith(';')) {
        sql = sql.substring(0, sql.length - 1);
      }

      final upperSql = sql.toUpperCase();

      if (!upperSql.contains("RETURNING") &&
          (upperSql.startsWith("INSERT") ||
              upperSql.startsWith("UPDATE") ||
              upperSql.startsWith("DELETE"))) {
        sql += " RETURNING *";
      }

      final result = await conn.execute(
        Sql.named(sql),
        parameters: substitutionValues,
      );

      if (result.isEmpty) return null;

      final List<T> list = [];
      for (var row in result) {
        final rowMap = row.toColumnMap();
        list.add(_mapRow(rowMap));
      }
      return list;
    } catch (e) {
      print("Error on execute SQL: $e");
      rethrow;
    } finally {
      await conn.close();
    }
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
