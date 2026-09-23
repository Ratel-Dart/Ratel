/// One `ORDER BY` term. Internal to the query builder; never exported.
class Order {
  /// The column to order by.
  final String column;

  /// Whether to order descending.
  final bool descending;

  /// Creates an ordering term.
  const Order(this.column, this.descending);
}
