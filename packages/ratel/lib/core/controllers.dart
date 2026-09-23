/// Registry of controller factories, consulted by generated route tables.
///
/// `$registerRatel()` registers the default constructor of every controller
/// that declares one, and the generated route table builds its controller
/// through [create] on the first matching request.
///
/// An application overrides a controller with [register] to construct it with
/// its own dependencies — typically from `Bindings.dependencies()`, which runs
/// before the server starts serving:
///
/// ```dart
/// class AppBindings extends Bindings {
///   @override
///   void dependencies() {
///     Injector.put(UserService());
///     RatelControllers.register<UserController>(
///       () => UserController(Injector.get<UserService>()),
///     );
///   }
/// }
/// ```
class RatelControllers {
  RatelControllers._();

  static final Map<Type, Function> _overrides = {};
  static final Map<Type, Function> _defaults = {};

  /// Registers [factory] as the way to build controller [T], replacing any
  /// previous override.
  static void register<T>(T Function() factory) => _overrides[T] = factory;

  /// Registers [factory] as the fallback for [T], used when the application
  /// registers no override.
  ///
  /// Generated code calls this for controllers that declare a usable
  /// no-argument constructor. Applications do not call this directly.
  static void registerDefault<T>(T Function() factory) =>
      _defaults[T] = factory;

  /// Builds controller [T], preferring an override over the generated default.
  ///
  /// Throws [StateError] when [T] has neither — the case where a controller
  /// takes constructor dependencies and nothing said how to supply them.
  static T create<T>() {
    final factory = _overrides[T] ?? _defaults[T];
    if (factory == null) {
      throw StateError(
        'No factory registered for controller $T. It has no no-argument '
        'constructor, so register one with RatelControllers.register<$T>(), '
        'typically from Bindings.dependencies().',
      );
    }
    return (factory as T Function())();
  }

  /// Removes every override and generated default. Intended for tests that
  /// register routes more than once in a single isolate.
  static void reset() {
    _overrides.clear();
    _defaults.clear();
  }
}
