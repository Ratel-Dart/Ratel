import '../dialect.dart';
import 'built_query.dart';
import 'condition.dart';
import 'order.dart';

/// A small fluent SELECT builder.
///
/// Identifiers are quoted per the dialect and values are bound as parameters.
/// Provide only trusted column/table names; values are always parameterized.
class Query {
  /// The table to select from.
  final String table;

  final List<String> _columns = [];
  final List<Condition> _conditions = [];
  final List<Order> _orders = [];
  int? _limit;
  int? _offset;

  /// Starts a query against [table].
  Query.from(this.table);

  /// Restricts the selected [columns] (defaults to `*`).
  Query select(List<String> columns) {
    _columns.addAll(columns);
    return this;
  }

  /// Adds an `AND` condition `column operator @param`.
  Query where(String column, String operator, Object? value) {
    _conditions.add(Condition(column, operator, value, 'AND'));
    return this;
  }

  /// Adds an `OR` condition.
  Query orWhere(String column, String operator, Object? value) {
    _conditions.add(Condition(column, operator, value, 'OR'));
    return this;
  }

  /// Orders by [column], ascending unless [descending].
  Query orderBy(String column, {bool descending = false}) {
    _orders.add(Order(column, descending));
    return this;
  }

  /// Limits the number of rows.
  Query limit(int count) {
    _limit = count;
    return this;
  }

  /// Skips [count] rows.
  Query offset(int count) {
    _offset = count;
    return this;
  }

  /// Renders the query for [dialect].
  BuiltQuery build(SqlDialect dialect) {
    final parameters = <String, Object?>{};
    final buffer = StringBuffer('SELECT ');
    buffer.write(
      _columns.isEmpty ? '*' : _columns.map(dialect.quoteIdentifier).join(', '),
    );
    buffer.write(' FROM ${dialect.quoteIdentifier(table)}');

    if (_conditions.isNotEmpty) {
      buffer.write(' WHERE ');
      for (var i = 0; i < _conditions.length; i++) {
        final condition = _conditions[i];
        if (i > 0) buffer.write(' ${condition.connector} ');
        final name = 'p$i';
        buffer.write(
          '${dialect.quoteIdentifier(condition.column)} '
          '${condition.operator} @$name',
        );
        parameters[name] = condition.value;
      }
    }

    if (_orders.isNotEmpty) {
      buffer.write(' ORDER BY ');
      buffer.write(
        _orders
            .map((o) => '${dialect.quoteIdentifier(o.column)} '
                '${o.descending ? 'DESC' : 'ASC'}')
            .join(', '),
      );
    }

    final pagination = dialect.limitOffset(limit: _limit, offset: _offset);
    if (pagination.isNotEmpty) buffer.write(' $pagination');

    return BuiltQuery(buffer.toString(), parameters);
  }
}
