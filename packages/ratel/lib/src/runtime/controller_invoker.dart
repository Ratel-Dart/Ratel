import 'dart:async';

typedef ControllerInvoker<C> = FutureOr<Object?> Function(
  C controller,
  List<Object?> arguments,
);
