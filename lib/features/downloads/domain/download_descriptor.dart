import 'package:path/path.dart' as p;

final RegExp _bookIdPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final RegExp _versionPattern = RegExp(r'^\d+\.\d+\.\d+$');
final RegExp _shaPattern = RegExp(r'^[a-f0-9]{64}$');

enum DownloadFileKind { manifest, chapter, audio }

class DownloadFile {
  const DownloadFile({
    required this.kind,
    required this.path,
    required this.url,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.sha256,
    this.chapterId,
  });

  factory DownloadFile.fromJson(Object? source, String label) {
    if (source is! Map<String, dynamic>) {
      throw FormatException('$label: expected an object.');
    }
    final kind = switch (source['kind']) {
      'manifest' => DownloadFileKind.manifest,
      'chapter' => DownloadFileKind.chapter,
      'audio' => DownloadFileKind.audio,
      _ => throw FormatException('$label.kind: unsupported value.'),
    };
    final path = _string(source['path'], '$label.path');
    if (!_isSafeRelative(path)) {
      throw FormatException('$label.path: unsafe relative path.');
    }
    final size = source['sizeBytes'];
    if (size is! int || size < 0) {
      throw FormatException('$label.sizeBytes: expected a positive integer.');
    }
    final sha = _string(source['sha256'], '$label.sha256');
    if (!_shaPattern.hasMatch(sha)) {
      throw FormatException('$label.sha256: expected 64 lowercase hex chars.');
    }
    final chapterId = source['chapterId'];
    if (kind == DownloadFileKind.chapter && chapterId is! String) {
      throw FormatException('$label.chapterId: required for chapters.');
    }
    return DownloadFile(
      kind: kind,
      path: path,
      url: _string(source['url'], '$label.url'),
      downloadUrl: _string(source['downloadUrl'], '$label.downloadUrl'),
      sizeBytes: size,
      sha256: sha,
      chapterId: chapterId is String ? chapterId : null,
    );
  }

  final DownloadFileKind kind;
  final String path;
  final String url;
  final String downloadUrl;
  final int sizeBytes;
  final String sha256;
  final String? chapterId;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'path': path,
    'url': url,
    'downloadUrl': downloadUrl,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    if (chapterId != null) 'chapterId': chapterId,
  };
}

class DownloadDescriptor {
  const DownloadDescriptor({
    required this.schemaVersion,
    required this.bookId,
    required this.packVersion,
    required this.totalBytes,
    required this.files,
  });

  factory DownloadDescriptor.fromJson(Object? source) {
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Descripteur invalide.');
    }
    if (source['schemaVersion'] != 1) {
      throw const FormatException(
        'Version de descripteur non prise en charge.',
      );
    }
    final bookId = _string(source['bookId'], 'descriptor.bookId');
    if (!_bookIdPattern.hasMatch(bookId)) {
      throw const FormatException('Identifiant de livre invalide.');
    }
    final packVersion = _string(
      source['packVersion'],
      'descriptor.packVersion',
    );
    if (!_versionPattern.hasMatch(packVersion)) {
      throw const FormatException('Version de pack invalide.');
    }
    final totalBytes = source['totalBytes'];
    if (totalBytes is! int || totalBytes < 0) {
      throw const FormatException('Taille totale invalide.');
    }
    final rawFiles = source['files'];
    if (rawFiles is! List || rawFiles.isEmpty) {
      throw const FormatException('Le descripteur ne contient aucun fichier.');
    }
    final files = <DownloadFile>[];
    final paths = <String>{};
    var manifestCount = 0;
    for (final (index, raw) in rawFiles.indexed) {
      final file = DownloadFile.fromJson(raw, 'descriptor.files[$index]');
      if (!paths.add(file.path)) {
        throw FormatException('Chemin dupliqué : ${file.path}.');
      }
      if (file.kind == DownloadFileKind.manifest) manifestCount++;
      files.add(file);
    }
    if (manifestCount != 1) {
      throw const FormatException('Le descripteur doit contenir un manifeste.');
    }
    if (files.fold<int>(0, (sum, file) => sum + file.sizeBytes) != totalBytes) {
      throw const FormatException('Taille totale incohérente.');
    }
    return DownloadDescriptor(
      schemaVersion: 1,
      bookId: bookId,
      packVersion: packVersion,
      totalBytes: totalBytes,
      files: List.unmodifiable(files),
    );
  }

  final int schemaVersion;
  final String bookId;
  final String packVersion;
  final int totalBytes;
  final List<DownloadFile> files;

  DownloadFile get manifest =>
      files.firstWhere((file) => file.kind == DownloadFileKind.manifest);

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'bookId': bookId,
    'packVersion': packVersion,
    'totalBytes': totalBytes,
    'files': [for (final file in files) file.toJson()],
  };
}

String _string(Object? value, String label) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$label: expected a non-empty string.');
  }
  return value;
}

bool _isSafeRelative(String value) {
  if (value.isEmpty || value.contains('\\') || value.contains('\u0000')) {
    return false;
  }
  final normalized = p.posix.normalize(value);
  if (normalized.startsWith('/') ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    return false;
  }
  return !p.posix.split(value).contains('..');
}
