final class EntrySignature {
  const EntrySignature({
    required this.takesArguments,
    required this.returnsFuture,
  });

  final bool takesArguments;
  final bool returnsFuture;
}
