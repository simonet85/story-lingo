import 'dart:math' as math;

import 'program_session.dart';

const int programLength = 28;

class ProgramProgress {
  const ProgramProgress({
    required this.daysCompleted,
    required this.currentDay,
    required this.doneToday,
    required this.streak,
    required this.shieldAvailable,
    required this.bestStreak,
    required this.totalMinutes,
    required this.totalSessions,
  });

  final int daysCompleted;
  final int currentDay;
  final bool doneToday;
  final int streak;
  final bool shieldAvailable;
  final int bestStreak;
  final int totalMinutes;
  final int totalSessions;

  bool get programComplete => daysCompleted >= programLength;
}

ProgramProgress computeProgramProgress(
  List<ProgramSession> sessions, {
  required DateTime now,
}) {
  final today = startOfLocalDay(now);
  final days = <DateTime>{
    for (final session in sessions) startOfLocalDay(session.date),
  }.toList()..sort();

  final doneToday = days.any((day) => isSameLocalDay(day, today));
  final daysCompleted = math.min(days.length, programLength);
  final bestStreak = _bestStreak(days);

  var streak = 0;
  var shieldAvailable = true;
  if (days.isNotEmpty) {
    final gap = daysBetweenLocalDays(days.last, today);
    final alive = gap <= 1;
    final shielded = gap == 2;
    if (alive || shielded) {
      streak = 1;
      shieldAvailable = !shielded;
      for (var i = days.length - 1; i > 0; i--) {
        final diff = daysBetweenLocalDays(days[i - 1], days[i]);
        if (diff == 1) {
          streak++;
        } else if (diff == 2 && shieldAvailable) {
          shieldAvailable = false;
          streak++;
        } else {
          break;
        }
      }
    }
  }

  final programComplete = daysCompleted >= programLength;
  final currentDay = programComplete
      ? programLength
      : doneToday
      ? math.max(daysCompleted, 1)
      : math.min(daysCompleted + 1, programLength);

  return ProgramProgress(
    daysCompleted: daysCompleted,
    currentDay: currentDay,
    doneToday: doneToday,
    streak: streak,
    shieldAvailable: shieldAvailable,
    bestStreak: bestStreak,
    totalMinutes: sessions.fold(0, (sum, session) => sum + session.minutes),
    totalSessions: sessions.length,
  );
}

int _bestStreak(List<DateTime> days) {
  if (days.isEmpty) return 0;
  var best = 1;
  var run = 1;
  var shieldAvailable = true;
  for (var i = 1; i < days.length; i++) {
    final diff = daysBetweenLocalDays(days[i - 1], days[i]);
    if (diff == 1) {
      run++;
    } else if (diff == 2 && shieldAvailable) {
      shieldAvailable = false;
      run++;
    } else {
      run = 1;
      shieldAvailable = true;
    }
    best = math.max(best, run);
  }
  return best;
}
