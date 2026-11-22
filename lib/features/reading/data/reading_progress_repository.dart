import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/prefs_keys.dart';
import '../domain/chapter_reading_state.dart';

class ReadingProgressRepository {
  ReadingProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  ChapterReadingState load(String bookId, String chapterId) {
    final rawPosition = _prefs.get(
      PrefsKeys.readingPosition(bookId, chapterId),
    );
    final rawCompleted = _prefs.get(
      PrefsKeys.readingCompleted(bookId, chapterId),
    );
    final rawUpdated = _prefs.get(PrefsKeys.readingUpdated(bookId, chapterId));

    return ChapterReadingState(
      paragraphId: rawPosition is String && rawPosition.isNotEmpty
          ? rawPosition
          : null,
      completed: rawCompleted is bool ? rawCompleted : false,
      updatedAt: rawUpdated is int
          ? DateTime.fromMillisecondsSinceEpoch(rawUpdated)
          : null,
    );
  }

  Future<void> savePosition(
    String bookId,
    String chapterId,
    String paragraphId,
  ) async {
    final now = DateTime.now();
    await _prefs.setString(
      PrefsKeys.readingPosition(bookId, chapterId),
      paragraphId,
    );
    await _prefs.setInt(
      PrefsKeys.readingUpdated(bookId, chapterId),
      now.millisecondsSinceEpoch,
    );
  }

  Future<void> clearPosition(String bookId, String chapterId) async {
    await _prefs.remove(PrefsKeys.readingPosition(bookId, chapterId));
    await _prefs.setInt(
      PrefsKeys.readingUpdated(bookId, chapterId),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> markCompleted(String bookId, String chapterId) async {
    final now = DateTime.now();
    await _prefs.setBool(PrefsKeys.readingCompleted(bookId, chapterId), true);
    await _prefs.remove(PrefsKeys.readingPosition(bookId, chapterId));
    await _prefs.setInt(
      PrefsKeys.readingUpdated(bookId, chapterId),
      now.millisecondsSinceEpoch,
    );
  }

  /// Writes a remote state without bumping the local timestamp.
  Future<void> applyRemote(
    String bookId,
    String chapterId, {
    required String? paragraphId,
    required bool completed,
    required int updatedAtMs,
  }) async {
    if (paragraphId == null || paragraphId.isEmpty) {
      await _prefs.remove(PrefsKeys.readingPosition(bookId, chapterId));
    } else {
      await _prefs.setString(
        PrefsKeys.readingPosition(bookId, chapterId),
        paragraphId,
      );
    }
    await _prefs.setBool(
      PrefsKeys.readingCompleted(bookId, chapterId),
      completed,
    );
    await _prefs.setInt(
      PrefsKeys.readingUpdated(bookId, chapterId),
      updatedAtMs,
    );
  }
}
