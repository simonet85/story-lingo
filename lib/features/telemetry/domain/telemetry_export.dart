import 'dart:convert';

import '../../onboarding/domain/user_prefs.dart';
import '../../program/domain/program_progress.dart';
import '../../program/domain/program_session.dart';
import '../../vocabulary/domain/review_queue.dart';
import '../../vocabulary/domain/srs_card.dart';
import 'telemetry_event.dart';

Map<String, Object?> buildTelemetryExport({
  required List<TelemetryEvent> events,
  required List<ProgramSession> sessions,
  required ProgramProgress progress,
  required List<SrsCard> cards,
  required UserPrefs prefs,
  required String packVersion,
  required int chapterCount,
  required DateTime exportedAt,
}) {
  final sortedSessions = [...sessions]..sort((a, b) => a.date.compareTo(b.date));
  final reviews = cards.fold<int>(0, (sum, card) => sum + card.reviews);

  return {
    'schemaVersion': 1,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'participant': {
      'level': prefs.level.id,
      'interests': prefs.interests,
    },
    'content': {
      'packVersion': packVersion,
      'chapters': chapterCount,
    },
    'program': {
      'daysCompleted': progress.daysCompleted,
      'currentDay': progress.currentDay,
      'doneToday': progress.doneToday,
      'streak': progress.streak,
      'bestStreak': progress.bestStreak,
      'shieldAvailable': progress.shieldAvailable,
      'totalMinutes': progress.totalMinutes,
      'totalSessions': progress.totalSessions,
      'programComplete': progress.programComplete,
      'sessions': [
        for (final session in sortedSessions)
          {
            'date': formatProgramDay(session.date),
            'minutes': session.minutes,
          },
      ],
    },
    'vocabulary': {
      'cards': cards.length,
      'reviews': reviews,
      'newStudiedToday': newWordsStudiedToday(cards, exportedAt),
      'dailyNewGoal': dailyNewWordGoal,
    },
    'events': [for (final event in events) event.toJson()],
  };
}

String encodeTelemetryExport({
  required List<TelemetryEvent> events,
  required List<ProgramSession> sessions,
  required ProgramProgress progress,
  required List<SrsCard> cards,
  required UserPrefs prefs,
  required String packVersion,
  required int chapterCount,
  required DateTime exportedAt,
}) {
  return const JsonEncoder.withIndent('  ').convert(
    buildTelemetryExport(
      events: events,
      sessions: sessions,
      progress: progress,
      cards: cards,
      prefs: prefs,
      packVersion: packVersion,
      chapterCount: chapterCount,
      exportedAt: exportedAt,
    ),
  );
}
