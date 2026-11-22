import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'pack_store.dart';

PackStore createPackStore({String? rootOverride}) =>
    IoPackStore(rootOverride: rootOverride);

bool isHostTestEnvironment() => Platform.environment['FLUTTER_TEST'] == 'true';

class IoPackStore implements PackStore {
  IoPackStore({this.rootOverride});

  final String? rootOverride;
  Directory? _root;

  @override
  bool get isSupported => true;

  @override
  Future<void> ensureRoot() async {
    await _ensureRoot();
  }

  Future<Directory> _ensureRoot() async {
    final existing = _root;
    if (existing != null) return existing;
    final String base;
    if (rootOverride != null) {
      base = rootOverride!;
    } else {
      final support = await getApplicationSupportDirectory();
      base = p.join(support.path, 'storylingo');
    }
    final directory = Directory(base);
    await directory.create(recursive: true);
    _root = directory;
    return directory;
  }

  Future<File> _file(String path) async {
    final root = await _ensureRoot();
    return File(p.joinAll([root.path, ...p.posix.split(_relative(path))]));
  }

  Future<Directory> _directory(String path) async {
    final root = await _ensureRoot();
    return Directory(p.joinAll([root.path, ...p.posix.split(_relative(path))]));
  }

  String _relative(String path) {
    final normalized = p.posix.normalize(path);
    if (normalized.isEmpty ||
        normalized == '.' ||
        normalized.startsWith('/') ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        path.contains('\\') ||
        path.contains('\u0000')) {
      throw ArgumentError.value(path, 'path', 'Unsafe pack path.');
    }
    return normalized;
  }

  @override
  Future<void> writeBytes(String path, List<int> bytes) async {
    final file = await _file(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<PackSink> openSink(String path) async {
    final file = await _file(path);
    await file.parent.create(recursive: true);
    return _IoPackSink(file);
  }

  @override
  Future<void> writeStringAtomic(String path, String value) async {
    final file = await _file(path);
    await file.parent.create(recursive: true);
    final temporary = File(
      '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await temporary.writeAsString(value, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<String?> readString(String path) async {
    final file = await _file(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final file = await _file(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> exists(String path) async {
    final root = await _ensureRoot();
    final target = p.joinAll([root.path, ...p.posix.split(_relative(path))]);
    return await FileSystemEntity.type(target) != FileSystemEntityType.notFound;
  }

  @override
  Future<void> rename(String from, String to) async {
    final source = await _file(from);
    final target = await _file(to);
    await target.parent.create(recursive: true);
    final sourceType = await FileSystemEntity.type(source.path);
    if (sourceType == FileSystemEntityType.notFound) {
      throw FileSystemException('Missing pack path', source.path);
    }
    await target.parent.create(recursive: true);
    if (sourceType == FileSystemEntityType.directory) {
      final directory = Directory(source.path);
      if (await target.exists()) {
        await _delete(target.path);
      }
      await directory.rename(target.path);
    } else {
      if (await target.exists()) await target.delete();
      await source.rename(target.path);
    }
  }

  @override
  Future<void> deleteTree(String path) async {
    final root = await _ensureRoot();
    final targetPath = p.joinAll([
      root.path,
      ...p.posix.split(_relative(path)),
    ]);
    await _delete(targetPath);
  }

  Future<void> _delete(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.notFound) return;
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  @override
  Future<List<String>> listNames(String path) async {
    final directory = await _directory(path);
    if (!await directory.exists()) return const [];
    final names = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      names.add(p.basename(entity.path));
    }
    names.sort();
    return names;
  }

  @override
  Future<String> absolutePath(String path) async {
    final root = await _ensureRoot();
    return p.joinAll([root.path, ...p.posix.split(_relative(path))]);
  }
}

class _IoPackSink implements PackSink {
  _IoPackSink(this._file) : _sink = _file.openWrite();

  final File _file;
  final IOSink _sink;
  bool _closed = false;

  @override
  void add(List<int> data) {
    if (_closed) throw StateError('Sink already closed.');
    _sink.add(data);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _sink.flush();
    await _sink.close();
  }

  @override
  Future<void> abort() async {
    if (!_closed) {
      _closed = true;
      try {
        await _sink.close();
      } catch (_) {
        // The file may already be unusable; deletion below is best effort.
      }
    }
    try {
      if (await _file.exists()) await _file.delete();
    } catch (_) {
      // Cleanup is best effort; the staging directory is removed as a whole.
    }
  }
}
