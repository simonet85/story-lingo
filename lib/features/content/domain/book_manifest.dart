import '../../onboarding/domain/user_level.dart';
import 'content_format_exception.dart';
import 'content_level.dart';
import 'json_reader.dart';

class BookManifest {
  const BookManifest({
    required this.schemaVersion,
    required this.packVersion,
    required this.id,
    required this.title,
    required this.titleFr,
    required this.author,
    required this.level,
    required this.descriptionFr,
    required this.chapters,
    this.isFree = true,
  });

  factory BookManifest.fromJson(Object? source) {
    final json = requireJsonObject(source, 'manifest');
    final schemaVersion = requireInt(json, 'schemaVersion', 'manifest');
    if (schemaVersion != 1) {
      throw ContentFormatException(
        'manifest.schemaVersion: unsupported version $schemaVersion.',
      );
    }
    final packVersion = requireString(json, 'packVersion', 'manifest');
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(packVersion)) {
      throw ContentFormatException(
        'manifest.packVersion: "$packVersion" is not a semver version.',
      );
    }

    final rawIsFree = json['isFree'];
    if (rawIsFree != null && rawIsFree is! bool) {
      throw ContentFormatException('manifest.isFree: expected a boolean.');
    }

    final chapters = <BookChapterSummary>[];
    final rawChapters = requireJsonList(json['chapters'], 'manifest.chapters');
    if (rawChapters.isEmpty) {
      throw ContentFormatException(
        'manifest.chapters: at least one chapter is required.',
      );
    }
    for (final (index, raw) in rawChapters.indexed) {
      chapters.add(
        BookChapterSummary.fromJson(raw, 'manifest.chapters[$index]'),
      );
    }

    final manifest = BookManifest(
      schemaVersion: schemaVersion,
      packVersion: packVersion,
      id: requireString(json, 'id', 'manifest'),
      title: requireString(json, 'title', 'manifest'),
      titleFr: requireString(json, 'titleFr', 'manifest'),
      author: requireString(json, 'author', 'manifest'),
      level: parseContentLevel(json['level'], 'manifest.level'),
      descriptionFr: requireString(json, 'descriptionFr', 'manifest'),
      chapters: List.unmodifiable(chapters),
      isFree: rawIsFree is bool ? rawIsFree : true,
    );
    manifest._validateChapters();
    return manifest;
  }

  final int schemaVersion;
  final String packVersion;
  final String id;
  final String title;
  final String titleFr;
  final String author;
  final UserLevel level;
  final String descriptionFr;
  final List<BookChapterSummary> chapters;
  final bool isFree;

  int get totalEstimatedMinutes =>
      chapters.fold(0, (sum, chapter) => sum + chapter.estimatedMinutes);

  int get totalNewWords =>
      chapters.fold(0, (sum, chapter) => sum + chapter.newWordCount);

  void _validateChapters() {
    final ids = <String>{};
    final numbers = <int>{};
    for (final chapter in chapters) {
      if (!ids.add(chapter.id)) {
        throw ContentFormatException(
          'manifest.chapters: duplicate chapter id "${chapter.id}".',
        );
      }
      if (!numbers.add(chapter.number)) {
        throw ContentFormatException(
          'manifest.chapters: duplicate chapter number ${chapter.number}.',
        );
      }
    }
    final expected = List<int>.generate(chapters.length, (index) => index + 1);
    final sorted = numbers.toList()..sort();
    if (sorted.length != expected.length ||
        !sorted.every((number) => expected.contains(number))) {
      throw ContentFormatException(
        'manifest.chapters: chapter numbers must run from 1 to '
        '${chapters.length} without gaps.',
      );
    }
  }
}

class BookChapterSummary {
  const BookChapterSummary({
    required this.id,
    required this.number,
    required this.title,
    this.asset,
    this.url,
    required this.estimatedMinutes,
    required this.newWordCount,
  });

  factory BookChapterSummary.fromJson(Object? source, String path) {
    final json = requireJsonObject(source, path);
    final asset = optionalString(json, 'asset', path);
    final url = optionalString(json, 'url', path);
    if ((asset == null) == (url == null)) {
      throw ContentFormatException(
        '$path: exactly one of "asset" or "url" is required.',
      );
    }
    return BookChapterSummary(
      id: requireString(json, 'id', path),
      number: requireIntAtLeast(json, 'number', path, 1),
      title: requireString(json, 'title', path),
      asset: asset,
      url: url,
      estimatedMinutes: requireIntInRange(
        json,
        'estimatedMinutes',
        path,
        min: 1,
        max: 30,
      ),
      newWordCount: requireIntAtLeast(json, 'newWordCount', path, 0),
    );
  }

  final String id;
  final int number;
  final String title;
  final String? asset;
  final String? url;
  final int estimatedMinutes;
  final int newWordCount;

  bool get isRemote => url != null;

  String get location => asset ?? url!;
}
