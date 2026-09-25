final class ClosedStringSink implements StringSink {
  @override
  void write(Object? object) => throw StateError('StreamSink is closed');

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      throw StateError('StreamSink is closed');

  @override
  void writeCharCode(int charCode) => throw StateError('StreamSink is closed');

  @override
  void writeln([Object? object = '']) =>
      throw StateError('StreamSink is closed');
}
