import 'parameter_location.dart';

/// One input a route reads, as the generator resolved it at build time.
///
/// This is the route's description of itself, not a value: it names the input,
/// says where it is read from, and carries the Dart type the handler declared.
/// `openApiSpec` turns a list of these into an operation's parameters.
class RouteParameter {
  /// The name the input is read under — the path segment, query key, header or
  /// cookie name.
  final String name;

  /// Where the value is read from.
  final ParameterLocation location;

  /// The type the handler declared for it.
  final Type type;

  /// Whether the request must carry it. A path segment always must; the rest
  /// must when the handler declared a non-nullable type.
  final bool isRequired;

  /// Describes one route input.
  const RouteParameter({
    required this.name,
    required this.location,
    required this.type,
    this.isRequired = false,
  });
}
