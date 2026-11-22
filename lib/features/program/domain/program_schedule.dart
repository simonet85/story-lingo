import 'dart:math' as math;

import '../../content/domain/book_manifest.dart';
import 'program_progress.dart';

/// Chapter proposed for a program day (1-based), cycling through the book.
BookChapterSummary chapterForDay(BookManifest manifest, int day) {
  final index = math.max(0, math.min(programLength - 1, day - 1));
  return manifest.chapters[index % manifest.chapters.length];
}
