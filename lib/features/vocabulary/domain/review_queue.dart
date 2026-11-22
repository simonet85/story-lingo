import 'srs_card.dart';

/// Pilot daily objective: the lower bound of the product's 10–20 new words.
const int dailyNewWordGoal = 10;

bool isSameLocalDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

int newWordsStudiedToday(Iterable<SrsCard> cards, DateTime now) {
  var count = 0;
  for (final card in cards) {
    final first = card.firstReviewedAt;
    if (first != null && isSameLocalDay(first, now)) count++;
  }
  return count;
}

class ReviewQueue {
  const ReviewQueue({
    required this.cards,
    required this.newStudiedToday,
    required this.dailyNewGoal,
  });

  final List<SrsCard> cards;
  final int newStudiedToday;
  final int dailyNewGoal;

  bool get isEmpty => cards.isEmpty;

  int get dueCount => cards.length;

  int get remainingNewAllowance =>
      (dailyNewGoal - newStudiedToday).clamp(0, dailyNewGoal);
}

/// New cards first (up to the remaining daily allowance), then scheduled cards
/// that are due, ordered by due date.
ReviewQueue buildReviewQueue(
  Iterable<SrsCard> cards, {
  required DateTime now,
  int dailyNewGoal = dailyNewWordGoal,
}) {
  final all = List<SrsCard>.of(cards);
  final studiedToday = newWordsStudiedToday(all, now);
  final allowance = (dailyNewGoal - studiedToday).clamp(0, dailyNewGoal);
  final nowUtc = now.toUtc();

  final fresh = <SrsCard>[];
  for (final card in all) {
    if (fresh.length >= allowance) break;
    if (card.card.lastReview == null) fresh.add(card);
  }

  final due = <SrsCard>[
    for (final card in all)
      if (card.card.lastReview != null && !card.card.due.isAfter(nowUtc)) card,
  ]..sort((a, b) => a.card.due.compareTo(b.card.due));

  return ReviewQueue(
    cards: List.unmodifiable([...fresh, ...due]),
    newStudiedToday: studiedToday,
    dailyNewGoal: dailyNewGoal,
  );
}
