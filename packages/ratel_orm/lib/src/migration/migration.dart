class Migration {
  final String id;

  final List<String> up;

  final List<String> down;

  const Migration({required this.id, required this.up, this.down = const []});
}
