import 'dart:math' as math;

/// One completed reading session, merged per local calendar day.
class ProgramSession {
  const ProgramSession({
    required this.date,
    required this.minutes,
    this.updatedAt,
  });

  final DateTime date;
  final int minutes;

  /// Local edit time, used by sync (older records omit it).
  final DateTime? updatedAt;

  Map<String, Object?> toJson() => {
    'date': formatProgramDay(date),
    'minutes': minutes,
    if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
  };

  static ProgramSession? fromJson(Object? source) {
    if (source is! Map) return null;
    final rawDate = source['date'];
    final rawMinutes = source['minutes'];
    if (rawDate is! String || rawMinutes is! int || rawMinutes < 1) {
      return null;
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return null;
    final rawUpdated = source['updatedAt'];
    return ProgramSession(
      date: startOfLocalDay(parsed),
      minutes: math.max(1, math.min(240, rawMinutes)),
      updatedAt: rawUpdated is int
          ? DateTime.fromMillisecondsSinceEpoch(rawUpdated)
          : null,
    );
  }
}

DateTime startOfLocalDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int daysBetweenLocalDays(DateTime a, DateTime b) {
  final from = DateTime.utc(a.year, a.month, a.day);
  final to = DateTime.utc(b.year, b.month, b.day);
  return to.difference(from).inDays;
}

String formatProgramDay(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
