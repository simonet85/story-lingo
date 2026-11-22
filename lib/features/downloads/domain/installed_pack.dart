import 'download_exception.dart';

class InstalledPack {
  const InstalledPack({
    required this.bookId,
    required this.title,
    required this.packVersion,
    required this.downloadedAt,
    required this.totalBytes,
    required this.fileCount,
    required this.baseUrl,
  });

  factory InstalledPack.fromJson(Object? source, String expectedBookId) {
    if (source is! Map<String, dynamic>) {
      throw const FormatException('Pack installé invalide.');
    }
    final bookId = source['bookId'];
    if (bookId is! String || bookId != expectedBookId) {
      throw const FormatException('Identifiant du pack incohérent.');
    }
    final packVersion = source['packVersion'];
    final title = source['title'];
    final downloadedAt = source['downloadedAt'];
    final totalBytes = source['totalBytes'];
    final fileCount = source['fileCount'];
    final baseUrl = source['baseUrl'];
    final parsedDate = downloadedAt is String
        ? DateTime.tryParse(downloadedAt)
        : null;
    if (packVersion is! String ||
        title is! String ||
        parsedDate == null ||
        totalBytes is! int ||
        fileCount is! int) {
      throw const FormatException('Métadonnées du pack invalides.');
    }
    return InstalledPack(
      bookId: bookId,
      title: title,
      packVersion: packVersion,
      downloadedAt: parsedDate,
      totalBytes: totalBytes,
      fileCount: fileCount,
      baseUrl: baseUrl is String ? baseUrl : '',
    );
  }

  final String bookId;
  final String title;
  final String packVersion;
  final DateTime downloadedAt;
  final int totalBytes;
  final int fileCount;
  final String baseUrl;

  bool hasUpdate(String availableVersion) =>
      _compareVersions(availableVersion, packVersion) > 0;

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'title': title,
    'packVersion': packVersion,
    'downloadedAt': downloadedAt.toUtc().toIso8601String(),
    'totalBytes': totalBytes,
    'fileCount': fileCount,
    'baseUrl': baseUrl,
  };
}

class DownloadIndex {
  const DownloadIndex({required this.packs});

  factory DownloadIndex.empty() => const DownloadIndex(packs: {});

  factory DownloadIndex.fromJson(Object? source) {
    if (source is! Map<String, dynamic> || source['packs'] is! Map) {
      throw const FormatException('Index de téléchargement invalide.');
    }
    final rawPacks = source['packs'] as Map;
    final packs = <String, InstalledPack>{};
    for (final entry in rawPacks.entries) {
      final bookId = entry.key;
      if (bookId is! String) continue;
      try {
        packs[bookId] = InstalledPack.fromJson(entry.value, bookId);
      } on FormatException {
        continue;
      }
    }
    return DownloadIndex(packs: Map.unmodifiable(packs));
  }

  final Map<String, InstalledPack> packs;

  int get totalBytes =>
      packs.values.fold(0, (sum, pack) => sum + pack.totalBytes);

  bool get isEmpty => packs.isEmpty;

  InstalledPack? operator [](String bookId) => packs[bookId];

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'packs': {
      for (final entry in packs.entries) entry.key: entry.value.toJson(),
    },
  };

  DownloadIndex withPack(InstalledPack pack) =>
      DownloadIndex(packs: Map.unmodifiable({...packs, pack.bookId: pack}));

  DownloadIndex without(String bookId) =>
      DownloadIndex(packs: Map.unmodifiable({...packs}..remove(bookId)));
}

class PackMetadata {
  const PackMetadata({required this.installed, required this.descriptor});

  final InstalledPack installed;
  final Map<String, dynamic> descriptor;
}

enum DownloadJobStatus { downloading, cancelling, error }

class DownloadJob {
  const DownloadJob({
    required this.bookId,
    required this.status,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.error,
  });

  factory DownloadJob.starting(String bookId, int totalBytes) => DownloadJob(
    bookId: bookId,
    status: DownloadJobStatus.downloading,
    bytesDownloaded: 0,
    totalBytes: totalBytes,
  );

  final String bookId;
  final DownloadJobStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final String? error;

  bool get isActive =>
      status == DownloadJobStatus.downloading ||
      status == DownloadJobStatus.cancelling;

  double get progress =>
      totalBytes <= 0 ? 0 : (bytesDownloaded / totalBytes).clamp(0, 1);

  int get percent => (progress * 100).round();

  DownloadJob copyWith({
    DownloadJobStatus? status,
    int? bytesDownloaded,
    int? totalBytes,
    String? error,
    bool clearError = false,
  }) => DownloadJob(
    bookId: bookId,
    status: status ?? this.status,
    bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
    totalBytes: totalBytes ?? this.totalBytes,
    error: clearError ? null : (error ?? this.error),
  );
}

String downloadErrorMessage(Object error) {
  if (error is DownloadException) return error.message;
  return 'Téléchargement impossible. Vérifiez votre connexion.';
}

String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes o';
  final kilo = bytes / 1000;
  if (kilo < 1000) return '${_oneDecimal(kilo)} ko';
  final mega = kilo / 1000;
  if (mega < 1000) return '${_oneDecimal(mega)} Mo';
  return '${_oneDecimal(mega / 1000)} Go';
}

int _compareVersions(String left, String right) {
  final a = left.split('.').map(int.tryParse).toList();
  final b = right.split('.').map(int.tryParse).toList();
  for (var index = 0; index < 3; index++) {
    final av = index < a.length ? (a[index] ?? 0) : 0;
    final bv = index < b.length ? (b[index] ?? 0) : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

String _oneDecimal(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
