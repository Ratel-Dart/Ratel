/// Declares the application's dependency registrations.
///
/// Implement [dependencies] to register services on the [Injector]; the server
/// runs it once at startup.
abstract class Bindings {
  void dependencies();
}
