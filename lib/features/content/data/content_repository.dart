import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/prefs/user_prefs_provider.dart';
import '../../downloads/application/download_providers.dart';
import '../domain/book_manifest.dart';
import '../domain/catalogue.dart';
import '../domain/chapter.dart';
import '../domain/content_format_exception.dart';
import '../domain/content_offline_exception.dart';
import 'catalogue_repository.dart';
import 'local_pack_content.dart';

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(),
);

// Content failures (offline, corrupt pack) are actionable immediately; the
// retry backoff would only delay the error message by minutes.
Duration? _noRetry(int retryCount, Object error) => null;

final localPackContentProvider = Provider<LocalPackContent>((ref) {
  return LocalPackContent(
    store: ref.watch(packStoreProvider),
    repository: ref.watch(downloadRepositoryProvider),
  );
});

final pilotBookProvider = FutureProvider<BookManifest>((ref) {
  return ref.watch(contentRepositoryProvider).loadPilotManifest();
});

final catalogueRepositoryProvider = Provider<CatalogueRepository?>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) return null;
  final repository = CatalogueRepository(
    baseUrl: baseUrl,
    preferences: ref.watch(prefsRepositoryProvider).preferences,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final installedManifestsProvider = FutureProvider<Map<String, BookManifest>>((
  ref,
) async {
  final index = await ref.watch(downloadIndexProvider.future);
  if (index.isEmpty) return const {};
  final local = ref.watch(localPackContentProvider);
  final manifests = <String, BookManifest>{};
  for (final bookId in index.packs.keys) {
    try {
      final manifest = await local.loadManifest(bookId);
      if (manifest != null) manifests[bookId] = manifest;
    } on ContentFormatException {
      // A corrupt pack is reported when the book itself is opened.
    }
  }
  return Map.unmodifiable(manifests);
});

final catalogueProvider = FutureProvider<CatalogueView>((ref) async {
  final embeddedPilot = await ref.watch(pilotBookProvider.future);
  final installed = await ref.watch(installedManifestsProvider.future);
  final pilot = installed[embeddedPilot.id] ?? embeddedPilot;
  final embedded = CatalogueBook.fromManifest(pilot);

  List<CatalogueBook> merge(List<CatalogueBook> networkBooks) {
    final books = <CatalogueBook>[];
    final seen = <String>{};
    // Content priority lives in bookManifestProvider: a downloaded pack wins
    // there. The catalogue entry keeps the remote packVersion so the card can
    // advertise an update (FR-12.15).
    for (final book in networkBooks) {
      if (!seen.add(book.id)) continue;
      books.add(book.id == pilot.id ? embedded : book);
    }
    for (final entry in installed.entries) {
      if (!seen.add(entry.key)) continue;
      books.add(
        entry.key == pilot.id
            ? embedded
            : CatalogueBook.fromManifest(entry.value, isEmbedded: false),
      );
    }
    if (!seen.contains(pilot.id)) books.add(embedded);
    return books;
  }

  final repository = ref.watch(catalogueRepositoryProvider);
  if (repository == null) {
    return CatalogueView(
      pilot: pilot,
      books: merge(const []),
      source: installed.isEmpty
          ? CatalogueSource.embedded
          : CatalogueSource.fallback,
    );
  }

  try {
    final result = await repository.loadCatalogue();
    return CatalogueView(
      pilot: pilot,
      books: merge(result.catalogue.books),
      source: result.fromCache
          ? (result.stale ? CatalogueSource.fallback : CatalogueSource.cache)
          : CatalogueSource.network,
    );
  } catch (_) {
    return CatalogueView(
      pilot: pilot,
      books: merge(const []),
      source: CatalogueSource.fallback,
    );
  }
}, retry: _noRetry);

final bookManifestProvider = FutureProvider.family<BookManifest, String>((
  ref,
  bookId,
) async {
  final index = await ref.watch(downloadIndexProvider.future);
  if (index.packs.containsKey(bookId)) {
    final local = ref.watch(localPackContentProvider);
    try {
      final manifest = await local.loadManifest(bookId);
      if (manifest != null) return manifest;
    } on ContentFormatException {
      throw ContentOfflineException(
        'Le livre téléchargé est endommagé. Retéléchargez-le.',
      );
    }
    throw ContentOfflineException(
      'Le livre téléchargé est introuvable. Téléchargez-le à nouveau.',
    );
  }

  final pilot = await ref.watch(pilotBookProvider.future);
  if (bookId == pilot.id) return pilot;
  final repository = ref.watch(catalogueRepositoryProvider);
  if (repository == null) {
    throw ContentFormatException('Unknown book "$bookId".');
  }
  try {
    return await repository.loadManifest(bookId);
  } on CatalogueException {
    throw ContentOfflineException(
      'Ce livre n’est pas téléchargé. Connectez-vous ou téléchargez le livre.',
    );
  }
}, retry: _noRetry);

typedef ChapterRequest = ({String bookId, String chapterId});

final chapterProvider = FutureProvider.family<Chapter, ChapterRequest>((
  ref,
  request,
) async {
  final index = await ref.watch(downloadIndexProvider.future);
  if (index.packs.containsKey(request.bookId)) {
    final local = ref.watch(localPackContentProvider);
    try {
      final chapter = await local.loadChapter(
        request.bookId,
        request.chapterId,
      );
      if (chapter != null) return chapter;
    } on ContentFormatException {
      throw ContentOfflineException(
        'Le chapitre téléchargé est endommagé. Retéléchargez le livre.',
      );
    }
    throw ContentOfflineException(
      'Le chapitre téléchargé est introuvable. Retéléchargez le livre.',
    );
  }

  final manifest = await ref.watch(bookManifestProvider(request.bookId).future);
  BookChapterSummary? summary;
  for (final chapter in manifest.chapters) {
    if (chapter.id == request.chapterId) {
      summary = chapter;
      break;
    }
  }
  if (summary == null) {
    throw ContentFormatException(
      'Chapter "${request.chapterId}" is not declared in manifest '
      '"${manifest.id}".',
    );
  }

  if (summary.asset != null) {
    return ref
        .watch(contentRepositoryProvider)
        .loadChapter(manifest: manifest, chapterId: request.chapterId);
  }
  final repository = ref.watch(catalogueRepositoryProvider);
  if (repository == null) {
    throw ContentOfflineException(
      'Ce chapitre n’est pas téléchargé. Connectez-vous ou téléchargez le livre.',
    );
  }
  try {
    return await repository.loadChapter(
      bookId: request.bookId,
      summary: summary,
    );
  } on CatalogueException {
    throw ContentOfflineException(
      'Ce chapitre n’est pas téléchargé. Connectez-vous ou téléchargez le livre.',
    );
  }
}, retry: _noRetry);

class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String pilotManifestAsset =
      'assets/content/sleepy-hollow-a2/manifest.json';

  final AssetBundle _bundle;

  Future<BookManifest> loadPilotManifest() {
    return loadManifest(pilotManifestAsset);
  }

  Future<BookManifest> loadManifest(String asset) async {
    return BookManifest.fromJson(await _loadJson(asset));
  }

  Future<Chapter> loadChapter({
    required BookManifest manifest,
    required String chapterId,
  }) async {
    BookChapterSummary? summary;
    for (final chapter in manifest.chapters) {
      if (chapter.id == chapterId) {
        summary = chapter;
        break;
      }
    }
    if (summary == null) {
      throw ContentFormatException(
        'Chapter "$chapterId" is not declared in manifest "${manifest.id}".',
      );
    }

    final asset = summary.asset;
    if (asset == null) {
      throw ContentFormatException(
        'Chapter "$chapterId" is served remotely, not from embedded assets.',
      );
    }
    final chapter = Chapter.fromJson(await _loadJson(asset));
    if (chapter.bookId != manifest.id) {
      throw ContentFormatException(
        'Chapter "${chapter.id}" belongs to "${chapter.bookId}", '
        'not "${manifest.id}".',
      );
    }
    if (chapter.id != summary.id || chapter.number != summary.number) {
      throw ContentFormatException(
        'Chapter "${chapter.id}" does not match manifest entry '
        '"${summary.id}" (number ${summary.number}).',
      );
    }
    return chapter;
  }

  Future<Object?> _loadJson(String asset) async {
    final String content;
    try {
      content = await _bundle.loadString(asset, cache: false);
    } on FlutterError catch (error) {
      throw ContentFormatException(
        'Unable to load content asset "$asset": ${error.message}',
      );
    }
    try {
      return jsonDecode(content);
    } on FormatException catch (error) {
      throw ContentFormatException(
        'Invalid JSON in "$asset": ${error.message}',
      );
    }
  }
}
