import 'dart:convert';
import 'dart:typed_data';

import 'package:storylingo/features/downloads/data/pack_store.dart';

class InMemoryPackStore implements PackStore {
  final Map<String, Uint8List> files = {};

  @override
  bool get isSupported => true;

  @override
  Future<void> ensureRoot() async {}

  @override
  Future<void> writeBytes(String path, List<int> bytes) async {
    files[path] = Uint8List.fromList(bytes);
  }

  @override
  Future<PackSink> openSink(String path) async {
    return _MemorySink((bytes) => files[path] = bytes);
  }

  @override
  Future<void> writeStringAtomic(String path, String value) async {
    files[path] = Uint8List.fromList(utf8.encode(value));
  }

  @override
  Future<String?> readString(String path) async {
    final bytes = files[path];
    return bytes == null ? null : utf8.decode(bytes);
  }

  @override
  Future<Uint8List?> readBytes(String path) async => files[path];

  @override
  Future<bool> exists(String path) async =>
      files.containsKey(path) || _hasChildren(path);

  @override
  Future<void> rename(String from, String to) async {
    final prefix = '$from/';
    final moved = <String, Uint8List>{
      for (final entry in files.entries)
        if (entry.key == from || entry.key.startsWith(prefix))
          entry.key: entry.value,
    };
    if (moved.isEmpty) {
      throw StateError('Missing pack path: $from');
    }
    for (final key in moved.keys) {
      files.remove(key);
    }
    for (final entry in moved.entries) {
      final suffix = entry.key == from
          ? ''
          : entry.key.substring(prefix.length);
      files[suffix.isEmpty ? to : '$to/$suffix'] = entry.value;
    }
  }

  @override
  Future<void> deleteTree(String path) async {
    files.removeWhere((key, value) => key == path || key.startsWith('$path/'));
  }

  @override
  Future<List<String>> listNames(String path) async {
    final prefix = '$path/';
    final names = <String>{};
    for (final key in files.keys) {
      if (!key.startsWith(prefix)) continue;
      final rest = key.substring(prefix.length);
      names.add(rest.split('/').first);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  @override
  Future<String> absolutePath(String path) async => '/memory/$path';

  bool _hasChildren(String path) => _hasPrefix(files, '$path/');

  bool _hasPrefix(Map<String, Uint8List> source, String prefix) {
    return source.keys.any((key) => key.startsWith(prefix));
  }
}

class _MemorySink implements PackSink {
  _MemorySink(this._commit);

  final void Function(Uint8List bytes) _commit;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  bool _closed = false;

  @override
  void add(List<int> data) {
    if (_closed) throw StateError('Sink already closed.');
    _builder.add(data);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _commit(_builder.takeBytes());
  }

  @override
  Future<void> abort() async {
    _closed = true;
    _builder.clear();
  }
}
