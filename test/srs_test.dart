import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Card, Rating;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/features/content/domain/chapter.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/domain/review_queue.dart';
import 'package:storylingo/features/vocabulary/domain/srs_card.dart';
import 'package:storylingo/features/vocabulary/domain/word_detection.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

Map<String, dynamic> _vocabulary(
  String id, {
  String pos = 'noun',
  String? cefr,
}) {
  return {
    'id': id,
    'word': id,
    'partOfSpeech': pos,
    'phonetic': '/$id/',
    'definitionEn': 'definition of $id',
    'translationFr': 'traduction de $id',
    'example': 'An example with $id.',
    'cefr': ?cefr,
  };
}

Chapter _chapter(List<Map<String, dynamic>> vocabulary) {
  final segments = <Map<String, dynamic>>[];
  for (final (index, word) in vocabulary.indexed) {
    segments.add({
      'text': '${word['id']}${index + 1 == vocabulary.length ? '.' : ' '}',
      'vocabId': word['id'],
    });
  }
  return Chapter.fromJson({
    'schemaVersion': 1,
    'id': 'chapter-01',
    'bookId': 'sleepy-hollow',
    'number': 1,
    'title': 'Chapitre de test',
    'level': 'a2',
    'paragraphs': <Map<String, dynamic>>[
      {'id': 'p-01', 'segments': segments},
    ],
    'vocabulary': vocabulary,
  });
}

WordEntry _entry(String id) => WordEntry(
  id: 'sleepy-hollow/$id',
  word: id,
  partOfSpeech: 'noun',
  phonetic: '/$id/',
  definitionEn: 'definition of $id',
  translationFr: 'traduction de $id',
  example: 'An example with $id.',
  bookId: 'sleepy-hollow',
  chapterId: 'chapter-01',
);

SrsCard _card(
  String id, {
  Card? card,
  DateTime? firstReviewedAt,
  DateTime? lastReviewedAt,
  DateTime? introducedAt,
  int reviews = 0,
}) {
  return SrsCard(
    entry: _entry(id),
    card: card ?? Card(cardId: srsCardIdFor('sleepy-hollow/$id')),
    introducedAt: introducedAt ?? DateTime.utc(2026, 11, 22, 8),
    firstReviewedAt: firstReviewedAt,
    lastReviewedAt: lastReviewedAt,
    reviews: reviews,
  );
}

void main() {
  group('srsCardIdFor', () {
    test('is stable and 32-bit', () {
      expect(srsCardIdFor('sleepy-hollow/mist'), srsCardIdFor('sleepy-hollow/mist'));
      expect(srsCardIdFor('sleepy-hollow/mist'), isNot(srsCardIdFor('sleepy-hollow/porch')));
      expect(srsCardIdFor('sleepy-hollow/mist'), inInclusiveRange(0, 0xFFFFFFFF));
    });
  });

  group('detectNewWords', () {
    final chapter = _chapter([
      _vocabulary('sleepy-hollow', pos: 'proper noun'),
      _vocabulary('mist', cefr: 'a2'),
      _vocabulary('porch', cefr: 'a2'),
      _vocabulary('whisper', cefr: 'b1'),
      _vocabulary('silence', cefr: 'b1'),
      _vocabulary('reputation', cefr: 'b2'),
      _vocabulary('omen'),
    ]);

    List<String> ids(List<WordEntry> entries) =>
        [for (final entry in entries) entry.id];

    test('keeps words at or above the user level and never proper nouns', () {
      final detected = detectNewWords(
        chapter: chapter,
        level: UserLevel.b1,
        introducedIds: const {},
      );

      expect(detected, hasLength(5));
      expect(ids(detected), containsAll(['sleepy-hollow/reputation', 'sleepy-hollow/omen']));
      expect(ids(detected), isNot(contains('sleepy-hollow/sleepy-hollow')));
      expect(
        ids(detected).where((id) => id == 'sleepy-hollow/porch'),
        isEmpty,
      );
    });

    test('fills the session with the hardest remaining words', () {
      final detected = detectNewWords(
        chapter: chapter,
        level: UserLevel.b2,
        introducedIds: const {},
      );

      expect(detected, hasLength(5));
      expect(ids(detected).first, 'sleepy-hollow/reputation');
      expect(ids(detected), isNot(contains('sleepy-hollow/sleepy-hollow')));
    });

    test('never revisits introduced words', () {
      final detected = detectNewWords(
        chapter: chapter,
        level: UserLevel.a2,
        introducedIds: {
          'sleepy-hollow/mist',
          'sleepy-hollow/porch',
          'sleepy-hollow/whisper',
          'sleepy-hollow/reputation',
        },
      );

      expect(ids(detected), isNot(contains('sleepy-hollow/mist')));
      expect(detected, hasLength(2));
    });

    test('saved words come first, even below the user level', () {
      final detected = detectNewWords(
        chapter: chapter,
        level: UserLevel.b2,
        introducedIds: const {},
        savedIds: {'sleepy-hollow/mist'},
      );

      expect(detected.first.id, 'sleepy-hollow/mist');
    });
  });

  group('buildReviewQueue', () {
    final now = DateTime(2026, 11, 22, 10);

    test('limits new cards to the remaining daily allowance', () {
      final cards = [for (var i = 0; i < 12; i++) _card('word-$i')];
      final queue = buildReviewQueue(cards, now: now);

      expect(queue.cards, hasLength(dailyNewWordGoal));
      expect(queue.newStudiedToday, 0);
      expect(queue.remainingNewAllowance, dailyNewWordGoal);
    });

    test('counts words first reviewed today', () {
      final cards = [
        for (var i = 0; i < 12; i++)
          _card(
            'word-$i',
            card: Card(
              cardId: srsCardIdFor('sleepy-hollow/word-$i'),
              due: now,
              lastReview: DateTime(2026, 11, 22, 9),
            ),
            firstReviewedAt: i < 3 ? DateTime(2026, 11, 22, 9) : DateTime(2026, 11, 21, 9),
            reviews: 1,
          ),
      ];
      final queue = buildReviewQueue(cards, now: now);

      expect(queue.newStudiedToday, 3);
      expect(queue.remainingNewAllowance, 7);
    });

    test('appends only due scheduled cards, ordered by due date', () {
      final cards = [
        _card(
          'later',
          card: Card(
            cardId: srsCardIdFor('sleepy-hollow/later'),
            due: now.add(const Duration(days: 1)),
            lastReview: now.subtract(const Duration(days: 3)),
          ),
          firstReviewedAt: DateTime(2026, 11, 18),
          reviews: 1,
        ),
        _card(
          'overdue',
          card: Card(
            cardId: srsCardIdFor('sleepy-hollow/overdue'),
            due: now.subtract(const Duration(days: 2)),
            lastReview: now.subtract(const Duration(days: 4)),
          ),
          firstReviewedAt: DateTime(2026, 11, 17),
          reviews: 1,
        ),
        _card(
          'due',
          card: Card(
            cardId: srsCardIdFor('sleepy-hollow/due'),
            due: now.subtract(const Duration(hours: 1)),
            lastReview: now.subtract(const Duration(days: 1)),
          ),
          firstReviewedAt: DateTime(2026, 11, 20),
          reviews: 1,
        ),
        _card('new'),
      ];
      final queue = buildReviewQueue(cards, now: now);

      final ids = [for (final card in queue.cards) card.entry.word];
      expect(ids, ['new', 'overdue', 'due']);
    });

    test('is empty when nothing is new or due', () {
      final queue = buildReviewQueue([], now: now);
      expect(queue.isEmpty, isTrue);
      expect(queue.dueCount, 0);
    });

    test('never caps due cards already reviewed', () {
      final cards = [
        for (var i = 0; i < 10; i++)
          _card(
            'studied-$i',
            card: Card(
              cardId: srsCardIdFor('sleepy-hollow/studied-$i'),
              due: now.add(const Duration(hours: 5)),
              lastReview: now.subtract(const Duration(hours: 1)),
            ),
            firstReviewedAt: DateTime(2026, 11, 22, 9),
            reviews: 1,
          ),
        for (var i = 0; i < 5; i++)
          _card(
            'due-$i',
            card: Card(
              cardId: srsCardIdFor('sleepy-hollow/due-$i'),
              due: now.subtract(const Duration(hours: 2)),
              lastReview: now.subtract(const Duration(days: 1)),
            ),
            firstReviewedAt: DateTime(2026, 11, 19),
            reviews: 1,
          ),
      ];
      final queue = buildReviewQueue(cards, now: now);

      expect(queue.remainingNewAllowance, 0);
      expect(queue.cards, hasLength(5));
      expect(
        [for (final card in queue.cards) card.entry.word],
        everyElement(startsWith('due-')),
      );
    });
  });

  group('SrsRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips a card with its schedule and review dates', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SrsRepository(prefs);
      final reviewed = DateTime.utc(2026, 11, 22, 9, 30);
      final card = _card(
        'mist',
        card: Card(
          cardId: srsCardIdFor('sleepy-hollow/mist'),
          due: DateTime.utc(2026, 11, 23, 9, 30),
          lastReview: reviewed,
        ),
        firstReviewedAt: reviewed,
        lastReviewedAt: reviewed,
        reviews: 1,
      );

      await repository.save([card]);
      final loaded = repository.load().single;

      expect(loaded.entry.id, 'sleepy-hollow/mist');
      expect(loaded.entry.word, 'mist');
      expect(loaded.card.state, card.card.state);
      expect(loaded.card.due, card.card.due);
      expect(loaded.card.lastReview, reviewed);
      expect(loaded.firstReviewedAt, reviewed);
      expect(loaded.lastReviewedAt, reviewed);
      expect(loaded.reviews, 1);
      expect(loaded.isNew, isFalse);
    });

    test('skips malformed entries and duplicates', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SrsRepository(prefs);
      final card = _card('mist');
      final payload = [
        jsonEncode(card.toJson()),
        jsonEncode(card.toJson()),
        '{not json',
        jsonEncode({'entry': null, 'card': null, 'introducedAt': 0}),
        42,
      ];
      await prefs.setStringList(PrefsKeys.srsCards, [
        for (final item in payload) item is String ? item : '$item',
      ]);

      final loaded = repository.load();

      expect(loaded, hasLength(1));
      expect(loaded.single.entry.id, 'sleepy-hollow/mist');
    });

    test('adds only the srs.cards preference key', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SrsRepository(prefs);

      await repository.save([_card('mist')]);

      expect(prefs.getKeys(), {PrefsKeys.srsCards});
    });
  });

  group('SrsController', () {
    final now = DateTime(2026, 11, 22, 10);
    late SharedPreferences prefs;
    late ProviderContainer container;

    SrsRepository repository() => SrsRepository(prefs);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          srsRepositoryProvider.overrideWithValue(repository()),
          nowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
    });

    test('introduces the chapter words once, persisting them', () async {
      final chapter = _chapter([
        _vocabulary('mist', cefr: 'a2'),
        _vocabulary('porch', cefr: 'a2'),
        _vocabulary('whisper', cefr: 'b1'),
        _vocabulary('silence', cefr: 'b1'),
        _vocabulary('reputation', cefr: 'b2'),
      ]);
      final controller = container.read(srsProvider.notifier);

      final added = await controller.introduceFromChapter(
        chapter: chapter,
        level: UserLevel.b1,
      );
      final again = await controller.introduceFromChapter(
        chapter: chapter,
        level: UserLevel.b1,
      );

      expect(added, 5);
      expect(again, 0);
      expect(container.read(srsProvider), hasLength(5));
      expect(repository().load(), hasLength(5));
    });

    test('rates a card with FSRS and tracks the first review', () async {
      final chapter = _chapter([_vocabulary('whisper', cefr: 'b1')]);
      final controller = container.read(srsProvider.notifier);
      await controller.introduceFromChapter(
        chapter: chapter,
        level: UserLevel.b1,
      );

      final updated = await controller.rate('sleepy-hollow/whisper', Rating.good);

      expect(updated, isNotNull);
      expect(updated!.reviews, 1);
      expect(updated.firstReviewedAt, now.toUtc());
      expect(updated.lastReviewedAt, now.toUtc());
      expect(updated.isNew, isFalse);
      expect(updated.card.due.isAfter(now.toUtc()), isTrue);
      expect(repository().load().single.reviews, 1);
    });

    test('returns null when rating an unknown word', () async {
      final controller = container.read(srsProvider.notifier);
      expect(await controller.rate('sleepy-hollow/mist', Rating.good), isNull);
    });

    test('Easy schedules farther than Good on a fresh card', () async {
      final chapter = _chapter([
        _vocabulary('mist', cefr: 'b1'),
        _vocabulary('porch', cefr: 'b1'),
      ]);
      final controller = container.read(srsProvider.notifier);
      await controller.introduceFromChapter(
        chapter: chapter,
        level: UserLevel.b1,
      );

      final good = await controller.rate('sleepy-hollow/mist', Rating.good);
      final easy = await controller.rate('sleepy-hollow/porch', Rating.easy);

      expect(good, isNotNull);
      expect(easy, isNotNull);
      expect(easy!.card.due.isAfter(good!.card.due), isTrue);
    });
  });
}
