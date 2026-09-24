import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

final class ProjectWatcher {
  ProjectWatcher(this.root) : _watcher = DirectoryWatcher(root);

  final String root;
  final DirectoryWatcher _watcher;
  final _batches = StreamController<Set<String>>();
  final Set<String> _pending = {};
  StreamSubscription<WatchEvent>? _subscription;
  Timer? _debounce;

  static const _debounceWindow = Duration(milliseconds: 150);
  static const _configFiles = {
    'pubspec.yaml',
    'pubspec.lock',
    'analysis_options.yaml',
  };

  Stream<Set<String>> get batches {
    _subscription ??= _watcher.events.listen(_onEvent);
    return _batches.stream;
  }

  Future<void> get ready => _watcher.ready;

  static bool isConfig(String path) => _configFiles.contains(p.basename(path));

  void _onEvent(WatchEvent event) {
    final path = p.normalize(event.path);
    if (!_isRelevant(path)) return;
    _pending.add(path);
    _debounce?.cancel();
    _debounce = Timer(_debounceWindow, () {
      final batch = {..._pending};
      _pending.clear();
      _batches.add(batch);
    });
  }

  bool _isRelevant(String path) {
    final segments = p.split(p.relative(path, from: root));
    if (segments
        .any((segment) => segment.startsWith('.') || segment == 'build')) {
      return false;
    }
    if (path.endsWith('.ratel.dart')) return false;
    return path.endsWith('.dart') || isConfig(path);
  }

  Future<void> close() async {
    _debounce?.cancel();
    await _subscription?.cancel();
    await _batches.close();
  }
}
