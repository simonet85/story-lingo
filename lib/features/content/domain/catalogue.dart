import '../../onboarding/domain/user_level.dart';
import 'book_manifest.dart';
import 'content_format_exception.dart';
import 'content_level.dart';
import 'json_reader.dart';

/// One book as advertised by the content API.
class CatalogueBook {
  const CatalogueBook({
    required this.id,
    required this.title,
    required this.titleFr,
    required this.author,
    required this.level,
    required this.descriptionFr,
    required this.packVersion,
    required this.chapterCount,
    required this.totalMinutes,
    required this.newWordCount,
    required this.isFree,
    required this.manifestUrl,
    this.isEmbedded = false,
  });

  factory CatalogueBook.fromJson(Object? source, String path) {
    final json = requireJsonObject(source, path);
    final id = requireString(json, 'id', path);
    final manifestUrl =
        optionalString(json, 'manifestUrl', path) ?? '/v1/books/$id';
    final isFree = json['isFree'];
    if (isFree != null && isFree is! bool) {
      throw ContentFormatException('$path.isFree: expected a boolean.');
    }
    return CatalogueBook(
      id: id,
      title: requireString(json, 'title', path),
      titleFr: requireString(json, 'titleFr', path),
      author: requireString(json, 'author', path),
      level: parseContentLevel(json['level'], '$path.level'),
      descriptionFr: requireString(json, 'descriptionFr', path),
      packVersion: requireString(json, 'packVersion', path),
      chapterCount: requireIntAtLeast(json, 'chapterCount', path, 1),
      totalMinutes: requireIntAtLeast(json, 'totalMinutes', path, 1),
      newWordCount: requireIntAtLeast(json, 'newWordCount', path, 0),
      isFree: isFree is bool ? isFree : true,
      manifestUrl: manifestUrl,
    );
  }

  factory CatalogueBook.fromManifest(
    BookManifest manifest, {
    bool isEmbedded = true,
  }) {
    return CatalogueBook(
      id: manifest.id,
      title: manifest.title,
      titleFr: manifest.titleFr,
      author: manifest.author,
      level: manifest.level,
      descriptionFr: manifest.descriptionFr,
      packVersion: manifest.packVersion,
      chapterCount: manifest.chapters.length,
      totalMinutes: manifest.totalEstimatedMinutes,
      newWordCount: manifest.totalNewWords,
      isFree: manifest.isFree,
      manifestUrl: '/v1/books/${manifest.id}',
      isEmbedded: isEmbedded,
    );
  }

  final String id;
  final String title;
  final String titleFr;
  final String author;
  final UserLevel level;
  final String descriptionFr;
  final String packVersion;
  final int chapterCount;
  final int totalMinutes;
  final int newWordCount;
  final bool isFree;
  final String manifestUrl;
  final bool isEmbedded;
}

class Catalogue {
  const Catalogue({required this.books, this.updatedAt});

  factory Catalogue.fromJson(Object? source) {
    final json = requireJsonObject(source, 'catalogue');
    final rawUpdatedAt = json['updatedAt'];
    final DateTime? updatedAt;
    if (rawUpdatedAt == null) {
      updatedAt = null;
    } else if (rawUpdatedAt is String) {
      updatedAt = DateTime.tryParse(rawUpdatedAt);
      if (updatedAt == null) {
        throw ContentFormatException(
          'catalogue.updatedAt: expected an ISO-8601 date.',
        );
      }
    } else {
      throw ContentFormatException(
        'catalogue.updatedAt: expected an ISO-8601 date.',
      );
    }

    final rawBooks = requireJsonList(json['books'], 'catalogue.books');
    final books = <CatalogueBook>[];
    final ids = <String>{};
    for (final (index, raw) in rawBooks.indexed) {
      final book = CatalogueBook.fromJson(raw, 'catalogue.books[$index]');
      if (!ids.add(book.id)) {
        throw ContentFormatException(
          'catalogue.books: duplicate book id "${book.id}".',
        );
      }
      books.add(book);
    }
    return Catalogue(books: List.unmodifiable(books), updatedAt: updatedAt);
  }

  final List<CatalogueBook> books;
  final DateTime? updatedAt;
}

enum CatalogueSource { embedded, network, cache, fallback }

class CatalogueView {
  const CatalogueView({
    required this.pilot,
    required this.books,
    required this.source,
  });

  final BookManifest pilot;
  final List<CatalogueBook> books;
  final CatalogueSource source;

  bool get isOffline =>
      source == CatalogueSource.cache || source == CatalogueSource.fallback;
}
