import '../dev/dev_session.dart';
import '../project/prepared_project.dart';

abstract final class DevCommand {
  static Future<int> run(List<String> arguments) async {
    final (entrypoint, appArguments) = _split(arguments);
    final prepared =
        await PreparedProject.prepare(entrypoint, needsEntrypoint: true);
    if (prepared == null) return 1;
    return DevSession(prepared, appArguments).run();
  }

  static (String?, List<String>) _split(List<String> arguments) {
    final separator = arguments.indexOf('--');
    final own = separator < 0 ? arguments : arguments.sublist(0, separator);
    final forwarded =
        separator < 0 ? const <String>[] : arguments.sublist(separator + 1);
    return (own.isEmpty ? null : own.first, forwarded);
  }
}
