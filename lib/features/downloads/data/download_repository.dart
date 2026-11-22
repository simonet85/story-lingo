import 'dart:convert';

import 'package:path/path.dart' as p;

import '../domain/download_descriptor.dart';
import '../domain/download_exception.dart';
import '../domain/installed_pack.dart';
import 'pack_store.dart';

class StoredPack {
  const StoredPack({required this.installed, required this.descriptor});

  final InstalledPack installed;
  final DownloadDescriptor descriptor;
}

class DownloadRepository {
  DownloadRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final PackStore store;
  final DateTime Function() _now;

  PackStore get _store => store;

  bool get isSupported => _store.isSupported;

  Future<DownloadIndex> reconcile() async {
    if (!_store.isSupported) return DownloadIndex.empty();
    await _store.ensureRoot();
    await _clearDirectory(PackPaths.staging);
    await _clearDirectory(PackPaths.trash);

    final previous = await loadIndex();
    final packs = <String, InstalledPack>{};
    for (final name in await _store.listNames(PackPaths.packs)) {
      final pack = await readPack(name);
      if (pack != null) packs[name] = pack.installed;
    }
    final index = DownloadIndex(packs: Map.unmodifiable(packs));
    if (_fingerprint(index) != _fingerprint(previous)) {
      await _writeIndexBestEffort(index);
    }
    return index;
  }

  Future<DownloadIndex> loadIndex() async {
    if (!_store.isSupported) return DownloadIndex.empty();
    try {
      final raw = await _store.readString(PackPaths.index);
      if (raw == null) return DownloadIndex.empty();
      return DownloadIndex.fromJson(jsonDecode(raw));
    } catch (_) {
      return DownloadIndex.empty();
    }
  }

  Future<StoredPack?> readPack(String bookId) async {
    if (!_store.isSupported) return null;
    try {
      final raw = await _store.readString(PackPaths.descriptor(bookId));
      final manifestRaw = await _store.readString(PackPaths.manifest(bookId));
      if (raw == null || manifestRaw == null) return null;
      final decoded = jsonDecode(raw);
      final manifest = jsonDecode(manifestRaw);
      if (decoded is! Map<String, dynamic> ||
          manifest is! Map<String, dynamic>) {
        return null;
      }
      final installed = InstalledPack.fromJson(decoded['installed'], bookId);
      final descriptor = DownloadDescriptor.fromJson(decoded['descriptor']);
      if (descriptor.bookId != bookId ||
          descriptor.packVersion != installed.packVersion ||
          manifest['id'] != bookId ||
          manifest['packVersion'] != installed.packVersion) {
        return null;
      }
      return StoredPack(installed: installed, descriptor: descriptor);
    } catch (_) {
      return null;
    }
  }

  Future<void> recordInstalled(InstalledPack pack) async {
    if (!_store.isSupported) return;
    final current = await loadIndex();
    await _writeIndexBestEffort(current.withPack(pack));
  }

  Future<void> remove(String bookId) async {
    if (!_store.isSupported) return;
    final index = await loadIndex();
    final source = PackPaths.pack(bookId);
    final trash = PackPaths.trashDirectory(
      bookId,
      _now().microsecondsSinceEpoch.toRadixString(36),
    );
    final exists = await _safeExists(source);
    if (exists) {
      try {
        await _store.rename(source, trash);
      } catch (_) {
        throw const DownloadStorageException(
          'Impossible de supprimer ce téléchargement.',
        );
      }
    }
    await _writeIndexBestEffort(index.without(bookId));
    if (exists) {
      try {
        await _store.deleteTree(trash);
      } catch (_) {
        // Cleaned at the next reconcile.
      }
    }
  }

  Future<String?> localAudioPath(String bookId, String url) async {
    final pack = await readPack(bookId);
    if (pack == null) return null;
    final targetPath = Uri.tryParse(url)?.path ?? url;
    final targetName = p.posix.basename(targetPath);
    for (final file in pack.descriptor.files) {
      if (file.kind != DownloadFileKind.audio) continue;
      final candidatePath = Uri.tryParse(file.url)?.path ?? file.url;
      final matches =
          candidatePath == targetPath ||
          p.posix.basename(candidatePath) == targetName;
      if (!matches) continue;
      final relative = PackPaths.relative(bookId, file.path);
      if (!await _safeExists(relative)) return null;
      return _store.absolutePath(relative);
    }
    return null;
  }

  Future<void> _clearDirectory(String directory) async {
    try {
      for (final name in await _store.listNames(directory)) {
        try {
          await _store.deleteTree('$directory/$name');
        } catch (_) {
          // Best effort; stale folders never affect installed packs.
        }
      }
    } catch (_) {
      // A missing directory is normal on first launch.
    }
  }

  Future<void> _writeIndexBestEffort(DownloadIndex index) async {
    try {
      await _store.writeStringAtomic(
        PackPaths.index,
        jsonEncode(index.toJson()),
      );
    } catch (_) {
      // The index is rebuilt from packs on the next reconcile.
    }
  }

  String _fingerprint(DownloadIndex index) => jsonEncode(index.toJson());

  Future<bool> _safeExists(String path) async {
    try {
      return await _store.exists(path);
    } catch (_) {
      return false;
    }
  }
}
