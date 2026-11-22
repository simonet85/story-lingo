import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/features/content/domain/book_manifest.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';
import 'package:storylingo/features/program/data/program_repository.dart';
import 'package:storylingo/features/program/domain/program_badges.dart';
import 'package:storylingo/features/program/domain/program_progress.dart';
import 'package:storylingo/features/program/domain/program_schedule.dart';
import 'package:storylingo/features/program/domain/program_session.dart';
import 'package:storylingo/features/program/presentation/program_provider.dart';
import 'package:storylingo/features/program/presentation/program_streak_chip.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

ProgramSession _session(int day, [int minutes = 10]) =>
    ProgramSession(date: DateTime(2026, 11, day), minutes: minutes);

ProgramProgress _progress({
  int daysCompleted = 0,
  int currentDay = 1,
  bool doneToday = false,
  int streak = 0,
  bool shieldAvailable = true,
  int bestStreak = 0,
  int totalMinutes = 0,
  int totalSessions = 0,
}) {
  return ProgramProgress(
    daysCompleted: daysCompleted,
    currentDay: currentDay,
    doneToday: doneToday,
    streak: streak,
    shieldAvailable: shieldAvailable,
    bestStreak: bestStreak,
    totalMinutes: totalMinutes,
    totalSessions: totalSessions,
  );
}

BookManifest _manifest(int chapterCount) {
  return BookManifest(
    schemaVersion: 1,
    packVersion: '1.0.0',
    id: 'book',
    title: 'Title',
    titleFr: 'Titre',
    author: 'Author',
    level: UserLevel.a2,
    descriptionFr: 'Description',
    chapters: [
      for (var number = 1; number <= chapterCount; number++)
        BookChapterSummary(
          id: 'chapter-0$number',
          number: number,
          title: 'Chapitre $number',
          asset: 'assets/chapter-$number.json',
          estimatedMinutes: 5,
          newWordCount: 3,
        ),
    ],
  );
}

void main() {
  group('ProgramSession', () {
    test('round-trips through JSON with a local day', () {
      final session = ProgramSession(
        date: DateTime(2026, 11, 22, 18, 45),
        minutes: 12,
      );

      final decoded = ProgramSession.fromJson(
        jsonDecode(jsonEncode(session.toJson())),
      );

      expect(decoded, isNotNull);
      expect(decoded!.date, DateTime(2026, 11, 22));
      expect(decoded.minutes, 12);
      expect(session.toJson()['date'], '2026-11-22');
    });

    test('rejects malformed sessions and clamps long durations', () {
      expect(ProgramSession.fromJson(null), isNull);
      expect(ProgramSession.fromJson('2026-11-22'), isNull);
      expect(ProgramSession.fromJson({'date': 'nope', 'minutes': 5}), isNull);
      expect(ProgramSession.fromJson({'date': '2026-11-22'}), isNull);
      expect(
        ProgramSession.fromJson({'date': '2026-11-22', 'minutes': 0}),
        isNull,
      );
      expect(
        ProgramSession.fromJson({'date': '2026-11-22', 'minutes': 999})!
            .minutes,
        240,
      );
    });

    test('compares and formats local days', () {
      expect(formatProgramDay(DateTime(2026, 1, 5)), '2026-01-05');
      expect(
        isSameLocalDay(DateTime(2026, 11, 22, 1), DateTime(2026, 11, 22, 23)),
        isTrue,
      );
      expect(
        daysBetweenLocalDays(DateTime(2026, 11, 20), DateTime(2026, 11, 22)),
        2,
      );
    });
  });

  group('ProgramRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists sessions and reloads them sorted', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = ProgramRepository(prefs);

      await repository.save([_session(22), _session(20, 5), _session(21, 7)]);

      final reloaded = ProgramRepository(prefs).load();
      expect(reloaded.map((session) => session.date.day), [20, 21, 22]);
      expect(reloaded.map((session) => session.minutes), [5, 7, 10]);
    });

    test(
      'ignores malformed entries, merges duplicate days at the maximum',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(PrefsKeys.programSessions, [
          jsonEncode(_session(22, 5).toJson()),
          jsonEncode(_session(22, 9).toJson()),
          jsonEncode({'date': 'invalid', 'minutes': 4}),
          jsonEncode({'date': '2026-11-21', 'minutes': 0}),
          '{not json',
          '42',
        ]);

        final loaded = ProgramRepository(prefs).load();

        expect(loaded, hasLength(1));
        expect(loaded.single.date, DateTime(2026, 11, 22));
        expect(loaded.single.minutes, 9);
      },
    );

    test('adds only the program.sessions preference key', () async {
      final prefs = await SharedPreferences.getInstance();
      await ProgramRepository(prefs).save([_session(22)]);

      expect(prefs.getKeys(), {PrefsKeys.programSessions});
    });
  });

  group('computeProgramProgress', () {
    test('starts at day 1 without any session', () {
      final progress = computeProgramProgress(
        const [],
        now: DateTime(2026, 11, 22),
      );

      expect(progress.daysCompleted, 0);
      expect(progress.currentDay, 1);
      expect(progress.doneToday, isFalse);
      expect(progress.streak, 0);
      expect(progress.shieldAvailable, isTrue);
      expect(progress.bestStreak, 0);
      expect(progress.programComplete, isFalse);
    });

    test('counts consecutive days and keeps the streak alive', () {
      final progress = computeProgramProgress([
        _session(20, 5),
        _session(21, 6),
        _session(22, 7),
      ], now: DateTime(2026, 11, 22, 21));

      expect(progress.daysCompleted, 3);
      expect(progress.currentDay, 3);
      expect(progress.doneToday, isTrue);
      expect(progress.streak, 3);
      expect(progress.bestStreak, 3);
      expect(progress.shieldAvailable, isTrue);
      expect(progress.totalMinutes, 18);
      expect(progress.totalSessions, 3);
    });

    test('proposes the next day when today is not completed', () {
      final progress = computeProgramProgress([
        _session(20),
        _session(21),
      ], now: DateTime(2026, 11, 22, 9));

      expect(progress.doneToday, isFalse);
      expect(progress.currentDay, 3);
      expect(progress.streak, 2);
      expect(progress.bestStreak, 2);
    });

    test('protects a single missed day with the shield', () {
      final progress = computeProgramProgress([
        _session(19),
        _session(20),
        _session(22),
      ], now: DateTime(2026, 11, 22));

      expect(progress.streak, 3);
      expect(progress.shieldAvailable, isFalse);
      expect(progress.bestStreak, 3);
    });

    test('uses the shield when the last session is two days old', () {
      final progress = computeProgramProgress([
        _session(20),
        _session(22),
      ], now: DateTime(2026, 11, 24));

      expect(progress.streak, 1);
      expect(progress.shieldAvailable, isFalse);
      expect(progress.doneToday, isFalse);
    });

    test('breaks the streak after two missed days', () {
      final progress = computeProgramProgress([
        _session(18),
        _session(19),
      ], now: DateTime(2026, 11, 22));

      expect(progress.streak, 0);
      expect(progress.shieldAvailable, isTrue);
      expect(progress.bestStreak, 2);
    });

    test('never shields two gaps in the same run', () {
      final progress = computeProgramProgress([
        _session(10),
        _session(11),
        _session(13),
        _session(15),
        _session(16),
      ], now: DateTime(2026, 11, 16));

      expect(progress.streak, 3);
      expect(progress.shieldAvailable, isFalse);
      expect(progress.bestStreak, 3);
    });

    test('caps the program at 28 days while keeping the totals', () {
      final sessions = [
        for (var index = 0; index < 30; index++)
          ProgramSession(
            date: DateTime(2026, 10, 24).add(Duration(days: index)),
            minutes: 10,
          ),
      ];
      final progress = computeProgramProgress(
        sessions,
        now: DateTime(2026, 11, 22),
      );

      expect(progress.daysCompleted, 28);
      expect(progress.currentDay, 28);
      expect(progress.programComplete, isTrue);
      expect(progress.totalSessions, 30);
      expect(progress.totalMinutes, 300);
    });
  });

  group('ProgramController', () {
    final now = DateTime(2026, 11, 22, 10);
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          programRepositoryProvider.overrideWithValue(ProgramRepository(prefs)),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'records one session per day and keeps the longest duration',
      () async {
        final controller = container.read(programProvider.notifier);

        await controller.recordSession(
          at: DateTime(2026, 11, 22, 23),
          elapsedSeconds: 61,
        );
        await controller.recordSession(
          at: DateTime(2026, 11, 22, 8),
          elapsedSeconds: 0,
        );
        await controller.recordSession(
          at: DateTime(2026, 11, 21, 8),
          elapsedSeconds: 5 * 60,
        );

        final sessions = container.read(programProvider);
        expect(sessions, hasLength(2));
        expect(sessions.first.date, DateTime(2026, 11, 21));
        expect(sessions.first.minutes, 5);
        expect(sessions.last.date, DateTime(2026, 11, 22));
        expect(sessions.last.minutes, 2);
      },
    );

    test('persists sessions for the next app start', () async {
      await container
          .read(programProvider.notifier)
          .recordSession(at: now, elapsedSeconds: 120);

      final second = ProviderContainer(
        overrides: [
          programRepositoryProvider.overrideWithValue(ProgramRepository(prefs)),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(second.dispose);

      final progress = second.read(programProgressProvider);
      expect(progress.daysCompleted, 1);
      expect(progress.doneToday, isTrue);
      expect(progress.totalMinutes, 2);
    });
  });

  group('chapterForDay', () {
    test('cycles through the book chapters', () {
      final manifest = _manifest(3);

      expect(chapterForDay(manifest, 1).number, 1);
      expect(chapterForDay(manifest, 3).number, 3);
      expect(chapterForDay(manifest, 4).number, 1);
      expect(chapterForDay(manifest, 28).number, 1);
    });

    test('repeats a single chapter and clamps the day', () {
      final manifest = _manifest(1);

      expect(chapterForDay(manifest, 1).id, 'chapter-01');
      expect(chapterForDay(manifest, 28).id, 'chapter-01');
      expect(chapterForDay(manifest, 0).id, 'chapter-01');
      expect(chapterForDay(manifest, 99).id, 'chapter-01');
    });
  });

  group('evaluateProgramBadges', () {
    test('locks every badge at the start', () {
      final badges = evaluateProgramBadges(
        progress: _progress(),
        vocabularyCards: 0,
      );

      expect(badges, hasLength(ProgramBadge.values.length));
      expect(badges.every((status) => !status.earned), isTrue);
      for (final badge in ProgramBadge.values) {
        expect(badge.title, isNotEmpty);
        expect(badge.description, isNotEmpty);
      }
    });

    test('unlocks day, streak and vocabulary badges at their thresholds', () {
      final progress = _progress(
        daysCompleted: 14,
        currentDay: 14,
        doneToday: true,
        streak: 7,
        bestStreak: 7,
      );

      final badges = {
        for (final status in evaluateProgramBadges(
          progress: progress,
          vocabularyCards: 10,
        ))
          status.badge: status.earned,
      };

      expect(badges[ProgramBadge.firstDay], isTrue);
      expect(badges[ProgramBadge.streak3], isTrue);
      expect(badges[ProgramBadge.streak7], isTrue);
      expect(badges[ProgramBadge.halfway], isTrue);
      expect(badges[ProgramBadge.complete], isFalse);
      expect(badges[ProgramBadge.tenWords], isTrue);
    });

    test('unlocks the final badge after 28 days', () {
      final badges = evaluateProgramBadges(
        progress: _progress(daysCompleted: 28, currentDay: 28),
        vocabularyCards: 2,
      );

      expect(
        badges
            .firstWhere((status) => status.badge == ProgramBadge.complete)
            .earned,
        isTrue,
      );
      expect(
        badges
            .firstWhere((status) => status.badge == ProgramBadge.tenWords)
            .earned,
        isFalse,
      );
    });
  });

  group('formatProgramMinutes', () {
    test('formats under and over an hour', () {
      expect(formatProgramMinutes(0), '0 min');
      expect(formatProgramMinutes(59), '59 min');
      expect(formatProgramMinutes(60), '1 h 00');
      expect(formatProgramMinutes(125), '2 h 05');
    });
  });
}
