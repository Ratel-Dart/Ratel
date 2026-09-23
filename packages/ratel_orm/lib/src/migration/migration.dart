/// A single, ordered schema change identified by [id].
///
/// [id] should sort in the intended order (e.g. `0001_create_notes`). [up]
/// holds the statements to apply and [down] the statements to revert them.
class Migration {
  /// A unique, sortable identifier.
  final String id;

  /// Statements applied, in order, to move the schema forward.
  final List<String> up;

  /// Statements applied, in order, to revert this migration.
  final List<String> down;

  /// Creates a migration.
  const Migration({required this.id, required this.up, this.down = const []});
}
