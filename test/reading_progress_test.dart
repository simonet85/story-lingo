import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/features/reading/data/reading_progress_repository.dart';
import 'package:storylingo/features/reading/domain/session_clock.dart';

void main() {
  group('formatSessionTime', () {
    test('formats remaining time', () {
      expect(formatSessionTime(360), '6:00');
      expect(formatSessionTime(59), '0:59');
      expect(formatSessionTime(0), '0:00');
    });

    test('formats overtime with a plus sign', () {
      expect(formatSessionTime(-1), '+0:01');
      expect(formatSessionTime(-65), '+1:05');
    });
  });

  group('SessionClock', () {
    test('counts ticks down from the total and into overtime', () {
      final clock = SessionClock(totalSeconds: 2);
      expect(clock.remainingSeconds, 2);

      clock.tick();
      clock.tick();
      expect(clock.remainingSeconds, 0);
      expect(clock.elapsedSeconds, 2);

      clock.tick();
      expect(clock.remainingSeconds, -1);
    });
  });

  group('ReadingProgressRepository', () {
    late ReadingProgressRepository repository;

    Future<void> setUpStore(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      repository = ReadingProgressRepository(
        await SharedPreferences.getInstance(),
      );
    }

    test('saves and reloads an anchor per chapter', () async {
      await setUpStore({});

      await repository.savePosition('sleepy-hollow', 'chapter-01', 'p-03');
      await repository.savePosition('sleepy-hollow', 'chapter-02', 'p-05');

      expect(
        repository.load('sleepy-hollow', 'chapter-01').paragraphId,
        'p-03',
      );
      expect(
        repository.load('sleepy-hollow', 'chapter-02').paragraphId,
        'p-05',
      );
      expect(repository.load('sleepy-hollow', 'chapter-01').completed, isFalse);
      expect(
        repository.load('sleepy-hollow', 'chapter-01').updatedAt,
        isNotNull,
      );
    });

    test('completion clears the anchor and persists', () async {
      await setUpStore({});

      await repository.savePosition('sleepy-hollow', 'chapter-01', 'p-04');
      await repository.markCompleted('sleepy-hollow', 'chapter-01');

      final state = repository.load('sleepy-hollow', 'chapter-01');
      expect(state.completed, isTrue);
      expect(state.paragraphId, isNull);
      expect(state.hasPosition, isFalse);
    });

    test('clearing the anchor keeps the completed flag', () async {
      await setUpStore({
        PrefsKeys.readingCompleted('sleepy-hollow', 'chapter-01'): true,
      });

      await repository.savePosition('sleepy-hollow', 'chapter-01', 'p-02');
      await repository.clearPosition('sleepy-hollow', 'chapter-01');

      final state = repository.load('sleepy-hollow', 'chapter-01');
      expect(state.paragraphId, isNull);
      expect(state.completed, isTrue);
    });

    test('ignores corrupted stored values', () async {
      await setUpStore({
        PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01'): 42,
        PrefsKeys.readingCompleted('sleepy-hollow', 'chapter-01'): 'yes',
        PrefsKeys.readingUpdated('sleepy-hollow', 'chapter-01'): 'now',
      });

      final state = repository.load('sleepy-hollow', 'chapter-01');
      expect(state.paragraphId, isNull);
      expect(state.completed, isFalse);
      expect(state.updatedAt, isNull);
    });
  });
}
