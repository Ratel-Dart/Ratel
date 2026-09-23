/// Maps an entity field to a database column.
///
/// Read by `RatelRepository` when mapping a query result row onto an entity.
class Column {
  /// The column name this field maps to.
  final String name;

  /// Annotates a field with its [name] column.
  const Column({required this.name});
}
