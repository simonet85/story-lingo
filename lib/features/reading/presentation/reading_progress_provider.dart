import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_progress_repository.dart';
import '../domain/chapter_reading_state.dart';

final readingProgressRepositoryProvider = Provider<ReadingProgressRepository>(
  (ref) => throw UnimplementedError(
    'readingProgressRepositoryProvider must be overridden at app start',
  ),
);

final readingProgressProvider =
    NotifierProvider<
      ReadingProgressController,
      Map<String, ChapterReadingState>
    >(ReadingProgressController.new);

String readingProgressKey(String bookId, String chapterId) =>
    '$bookId/$chapterId';

class ReadingProgressController
    extends Notifier<Map<String, ChapterReadingState>> {
  @override
  Map<String, ChapterReadingState> build() => const {};

  ChapterReadingState stateFor(String bookId, String chapterId) {
    return state[readingProgressKey(bookId, chapterId)] ??
        ref.read(readingProgressRepositoryProvider).load(bookId, chapterId);
  }

  Future<void> savePosition(
    String bookId,
    String chapterId,
    String paragraphId,
  ) async {
    await ref
        .read(readingProgressRepositoryProvider)
        .savePosition(bookId, chapterId, paragraphId);
    final completed = stateFor(bookId, chapterId).completed;
    state = {
      ...state,
      readingProgressKey(bookId, chapterId): ChapterReadingState(
        paragraphId: paragraphId,
        completed: completed,
        updatedAt: DateTime.now(),
      ),
    };
  }

  Future<void> clearPosition(String bookId, String chapterId) async {
    await ref
        .read(readingProgressRepositoryProvider)
        .clearPosition(bookId, chapterId);
    final completed = stateFor(bookId, chapterId).completed;
    state = {
      ...state,
      readingProgressKey(bookId, chapterId): ChapterReadingState(
        completed: completed,
        updatedAt: DateTime.now(),
      ),
    };
  }

  Future<void> complete(String bookId, String chapterId) async {
    await ref
        .read(readingProgressRepositoryProvider)
        .markCompleted(bookId, chapterId);
    state = {
      ...state,
      readingProgressKey(bookId, chapterId): ChapterReadingState(
        completed: true,
        updatedAt: DateTime.now(),
      ),
    };
  }
}
