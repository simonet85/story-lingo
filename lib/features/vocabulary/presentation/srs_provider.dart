import 'package:fsrs/fsrs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/domain/chapter.dart';
import '../../onboarding/domain/user_level.dart';
import '../data/srs_repository.dart';
import '../domain/review_queue.dart';
import '../domain/srs_card.dart';
import '../domain/word_detection.dart';

final srsRepositoryProvider = Provider<SrsRepository>(
  (ref) => throw UnimplementedError(
    'srsRepositoryProvider must be overridden at app start',
  ),
);

final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final srsSchedulerProvider = Provider<Scheduler>(
  (ref) => Scheduler(enableFuzzing: false),
);

final srsProvider = NotifierProvider<SrsController, List<SrsCard>>(
  SrsController.new,
);

final reviewQueueProvider = Provider<ReviewQueue>((ref) {
  final now = ref.read(nowProvider)();
  return buildReviewQueue(ref.watch(srsProvider), now: now);
});

class SrsController extends Notifier<List<SrsCard>> {
  @override
  List<SrsCard> build() => ref.watch(srsRepositoryProvider).load();

  bool contains(String entryId) =>
      state.any((card) => card.entry.id == entryId);

  /// Creates cards for the chapter's new words and returns how many were added.
  Future<int> introduceFromChapter({
    required Chapter chapter,
    required UserLevel level,
    Set<String> savedIds = const {},
  }) async {
    final detected = detectNewWords(
      chapter: chapter,
      level: level,
      introducedIds: {for (final card in state) card.entry.id},
      savedIds: savedIds,
    );
    if (detected.isEmpty) return 0;

    final now = ref.read(nowProvider)().toUtc();
    final next = <SrsCard>[
      ...state,
      for (final entry in detected)
        SrsCard(
          entry: entry,
          card: Card(cardId: srsCardIdFor(entry.id), due: now),
          introducedAt: now,
          reviews: 0,
        ),
    ];
    await _persist(next);
    return detected.length;
  }

  Future<SrsCard?> rate(String entryId, Rating rating) async {
    final index = state.indexWhere((card) => card.entry.id == entryId);
    if (index < 0) return null;

    final current = state[index];
    final now = ref.read(nowProvider)().toUtc();
    final result = ref.read(srsSchedulerProvider).reviewCard(
      current.card,
      rating,
      reviewDateTime: now,
    );
    final updated = SrsCard(
      entry: current.entry,
      card: result.card,
      introducedAt: current.introducedAt,
      firstReviewedAt: current.firstReviewedAt ?? now,
      lastReviewedAt: now,
      reviews: current.reviews + 1,
    );

    final next = [...state];
    next[index] = updated;
    await _persist(next);
    return updated;
  }

  Future<void> _persist(List<SrsCard> next) async {
    await ref.read(srsRepositoryProvider).save(next);
    state = List.unmodifiable(next);
  }
}
