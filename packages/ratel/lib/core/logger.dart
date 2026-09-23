import 'package:logging/logging.dart';

/// Shared logger for the Ratel framework.
///
/// The framework never configures global logging itself. Applications opt in by
/// attaching a handler to the root logger, for example:
///
/// ```dart
/// import 'package:logging/logging.dart';
///
/// void main() {
///   Logger.root.level = Level.INFO;
///   Logger.root.onRecord.listen((r) => print('${r.level.name}: ${r.message}'));
///   // ... start the server
/// }
/// ```
final Logger ratelLogger = Logger('ratel');
