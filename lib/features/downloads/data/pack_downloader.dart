import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../domain/download_descriptor.dart';
import '../domain/download_exception.dart';
import '../domain/installed_pack.dart';
import 'pack_store.dart';

typedef DownloadProgress = void Function(int completedBytes, int totalBytes);

class PackDownloader {
  PackDownloader({
    required this.store,
    required String baseUrl,
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 30),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _now = now ?? DateTime.now;

  final PackStore store;
  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  final Duration timeout;

  bool _active = false;
  int _tokenCounter = 0;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  String _newToken() {
    _tokenCounter++;
    return '${_now().microsecondsSinceEpoch.toRadixString(36)}-$_tokenCounter';
  }

  Uri _resolve(String location) {
    final uri = Uri.parse(location);
    if (uri.hasScheme) return uri;
    final path = location.startsWith('/') ? location : '/$location';
    return Uri.parse('$_baseUrl$path');
  }

  Future<DownloadDescriptor> fetchDescriptor(
    String bookId, {
    DownloadCancelToken? cancelToken,
  }) async {
    if (!store.isSupported) {
      throw const DownloadUnsupportedException(
        'Le téléchargement hors-ligne est disponible sur mobile uniquement.',
      );
    }
    if (_baseUrl.isEmpty) {
      throw const DownloadConfigException(
        'Aucun serveur de contenu configuré. Relancez l’application avec '
        'API_BASE_URL.',
      );
    }
    cancelToken?.throwIfCancelled();
    final uri = Uri.parse(
      '$_baseUrl/v1/books/${Uri.encodeComponent(bookId)}/download',
    );
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } catch (_) {
      throw const DownloadNetworkException(
        'Connexion impossible. Vérifiez votre réseau puis réessayez.',
      );
    }
    cancelToken?.throwIfCancelled();
    if (response.statusCode == 404) {
      throw const DownloadHttpException(
        'Ce livre n’est pas disponible au téléchargement.',
      );
    }
    if (response.statusCode != 200) {
      throw DownloadHttpException(
        'Le serveur a répondu ${response.statusCode}. Réessayez plus tard.',
      );
    }
    final DownloadDescriptor descriptor;
    try {
      descriptor = DownloadDescriptor.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    } on FormatException {
      throw const DownloadIntegrityException(
        'La description du téléchargement est invalide.',
      );
    }
    if (descriptor.bookId != bookId) {
      throw const DownloadIntegrityException(
        'La description ne correspond pas au livre demandé.',
      );
    }
    return descriptor;
  }

  Future<InstalledPack> download({
    required String bookId,
    DownloadProgress? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    if (_active) {
      throw const DownloadBusyException(
        'Un téléchargement est déjà en cours. Attendez qu’il se termine.',
      );
    }
    _active = true;
    String? staging;
    try {
      final descriptor = await fetchDescriptor(
        bookId,
        cancelToken: cancelToken,
      );
      final stagingDirectory = PackPaths.stagingDirectory(bookId, _newToken());
      staging = stagingDirectory;
      await _guardStorage(() => store.deleteTree(stagingDirectory));
      var completedBytes = 0;
      onProgress?.call(0, descriptor.totalBytes);
      for (final file in descriptor.files) {
        cancelToken?.throwIfCancelled();
        await _downloadFile(
          file,
          staging: stagingDirectory,
          onChunk: (bytes) {
            completedBytes += bytes;
            onProgress?.call(completedBytes, descriptor.totalBytes);
          },
          cancelToken: cancelToken,
        );
      }

      final manifest = await _readManifest(stagingDirectory);
      final title = manifest['title'] is String
          ? manifest['title'] as String
          : bookId;
      final installed = InstalledPack(
        bookId: bookId,
        title: title,
        packVersion: descriptor.packVersion,
        downloadedAt: _now().toUtc(),
        totalBytes: descriptor.totalBytes,
        fileCount: descriptor.files.length,
        baseUrl: _baseUrl,
      );
      await _guardStorage(
        () => store.writeStringAtomic(
          '$stagingDirectory/pack.json',
          jsonEncode({
            'schemaVersion': 1,
            'installed': installed.toJson(),
            'descriptor': descriptor.toJson(),
          }),
        ),
      );
      await _commit(bookId, stagingDirectory, cancelToken);
      staging = null;
      return installed;
    } on DownloadException {
      rethrow;
    } finally {
      if (staging != null) {
        try {
          await store.deleteTree(staging);
        } catch (_) {
          // Reconcile cleans leftovers on the next launch.
        }
      }
      _active = false;
    }
  }

  Future<void> _downloadFile(
    DownloadFile file, {
    required String staging,
    required void Function(int bytes) onChunk,
    DownloadCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final request = http.Request('GET', _resolve(file.downloadUrl))
      ..headers.addAll(const {'Accept': '*/*', 'Accept-Encoding': 'identity'});
    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } catch (_) {
      throw const DownloadNetworkException(
        'Connexion interrompue pendant le téléchargement.',
      );
    }
    if (response.statusCode != 200) {
      throw DownloadHttpException(
        'Le serveur a répondu ${response.statusCode} pour ${file.path}.',
      );
    }

    final PackSink sink;
    try {
      sink = await store.openSink('$staging/${file.path}');
    } catch (_) {
      throw const DownloadStorageException(
        'Espace de stockage insuffisant ou inaccessible.',
      );
    }
    final digestSink = _DigestSink();
    final hash = sha256.startChunkedConversion(digestSink);
    var received = 0;
    var closed = false;
    try {
      await for (final chunk in response.stream.timeout(timeout)) {
        cancelToken?.throwIfCancelled();
        received += chunk.length;
        if (received > file.sizeBytes) {
          throw const DownloadIntegrityException(
            'Un fichier téléchargé dépasse sa taille annoncée.',
          );
        }
        hash.add(chunk);
        sink.add(chunk);
        onChunk(chunk.length);
      }
      await sink.close();
      closed = true;
      hash.close();
      final digest = digestSink.value?.toString();
      if (received != file.sizeBytes || digest != file.sha256) {
        throw DownloadIntegrityException(
          'Le fichier ${file.path} est corrompu. Réessayez le téléchargement.',
        );
      }
    } on DownloadCancelledException {
      if (!closed) await sink.abort();
      rethrow;
    } on DownloadException {
      if (!closed) await sink.abort();
      rethrow;
    } catch (_) {
      if (!closed) await sink.abort();
      throw const DownloadNetworkException(
        'Le téléchargement a échoué. Vérifiez votre connexion.',
      );
    }
  }

  Future<Map<String, dynamic>> _readManifest(String staging) async {
    final raw = await _guardStorage(
      () => store.readString('$staging/manifest.json'),
    );
    if (raw == null) {
      throw const DownloadIntegrityException(
        'Le manifeste téléchargé est introuvable.',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through to the integrity error below.
    }
    throw const DownloadIntegrityException(
      'Le manifeste téléchargé est invalide.',
    );
  }

  Future<void> _commit(
    String bookId,
    String staging,
    DownloadCancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    final target = PackPaths.pack(bookId);
    final trash = PackPaths.trashDirectory(bookId, _newToken());
    final hadTarget = await _guardStorage(() => store.exists(target));
    try {
      if (hadTarget) {
        await store.rename(target, trash);
      }
      await store.rename(staging, target);
    } catch (_) {
      if (hadTarget && !await _safeExists(target) && await _safeExists(trash)) {
        try {
          await store.rename(trash, target);
        } catch (_) {
          // Reconcile will report the backup through available directories.
        }
      }
      throw const DownloadStorageException(
        'Impossible d’installer le livre téléchargé. Réessayez.',
      );
    }
    if (hadTarget) {
      try {
        await store.deleteTree(trash);
      } catch (_) {
        // Leftover trash is cleaned at the next reconcile.
      }
    }
  }

  Future<bool> _safeExists(String path) async {
    try {
      return await store.exists(path);
    } catch (_) {
      return false;
    }
  }

  Future<T> _guardStorage<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DownloadException {
      rethrow;
    } catch (_) {
      throw const DownloadStorageException(
        'Espace de stockage insuffisant ou inaccessible.',
      );
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
