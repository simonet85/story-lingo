import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/activity_table.dart';
import '../../program/domain/program_session.dart';
import '../../program/presentation/program_provider.dart';
import '../../telemetry/domain/telemetry_event.dart';
import '../../telemetry/presentation/telemetry_provider.dart';
import '../../vocabulary/domain/srs_card.dart';
import '../../vocabulary/presentation/srs_provider.dart';

class DashboardStats {
  const DashboardStats({
    required this.streak,
    required this.minutesLast7Days,
    required this.chaptersCompleted,
    required this.wordsMastered,
    required this.activity,
  });

  final int streak;
  final int minutesLast7Days;
  final int chaptersCompleted;
  final int wordsMastered;
  final List<ActivityEntry> activity;
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final now = ref.watch(nowProvider)();
  return buildDashboardStats(
    now: now,
    sessions: ref.watch(programProvider),
    cards: ref.watch(srsProvider),
    events: ref.watch(telemetryProvider),
    streak: ref.watch(programProgressProvider).streak,
  );
});

DashboardStats buildDashboardStats({
  required DateTime now,
  required List<ProgramSession> sessions,
  required List<SrsCard> cards,
  required List<TelemetryEvent> events,
  required int streak,
}) {
  final weekStart = startOfLocalDay(now).subtract(const Duration(days: 6));
  final minutes = sessions
      .where((session) => !startOfLocalDay(session.date).isBefore(weekStart))
      .fold<int>(0, (sum, session) => sum + session.minutes);

  final chapterIds = <String>{};
  for (final event in events) {
    if (event.name != 'chapter_completed') continue;
    final id = event.properties['chapterId'];
    if (id is String && id.isNotEmpty) {
      chapterIds.add(id);
    } else {
      final number = event.properties['chapterNumber'];
      if (number != null) chapterIds.add('chapitre-$number');
    }
  }

  final mastered = cards
      .where((card) => card.reviews >= AppSizes.masteredReviewCount)
      .length;

  final activity = <ActivityEntry>[];
  for (final event in events.reversed) {
    if (activity.length >= 8) break;
    final entry = _activityFor(event);
    if (entry != null) activity.add(entry);
  }

  return DashboardStats(
    streak: streak,
    minutesLast7Days: minutes,
    chaptersCompleted: chapterIds.length,
    wordsMastered: mastered,
    activity: List.unmodifiable(activity),
  );
}

ActivityEntry? _activityFor(TelemetryEvent event) {
  switch (event.name) {
    case 'chapter_completed':
      final number = event.properties['chapterNumber'];
      final minutes = event.properties['minutes'];
      final newWords = event.properties['newWords'];
      final details = <String>[
        if (minutes is num) '$minutes min de lecture',
        if (newWords is num && newWords > 0)
          '$newWords ${newWords == 1 ? 'nouveau mot' : 'nouveaux mots'}',
      ];
      return ActivityEntry(
        icon: Icons.menu_book_outlined,
        title: number is num ? 'Chapitre $number terminé' : 'Chapitre terminé',
        detail: details.isEmpty ? 'Lecture terminée' : details.join(' · '),
        at: event.at,
      );
    case 'review_completed':
      final reviewed = event.properties['reviewed'];
      return ActivityEntry(
        icon: Icons.school_outlined,
        title: 'Révision terminée',
        detail: reviewed is num
            ? '$reviewed ${reviewed == 1 ? 'carte révisée' : 'cartes révisées'}'
            : 'Révision terminée',
        at: event.at,
      );
  }
  return null;
}
