final class UnprintableFailure implements Exception {
  @override
  String toString() => throw StateError('toString broke');
}
