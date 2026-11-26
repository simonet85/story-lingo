import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' show Card;
import 'package:storylingo/core/ui/activity_table.dart';
import 'package:storylingo/features/program/domain/program_session.dart';
import 'package:storylingo/features/telemetry/domain/telemetry_event.dart';
import 'package:storylingo/features/today/presentation/dashboard_stats_provider.dart';
import 'package:storylingo/features/vocabulary/domain/srs_card.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';

WordEntry _entry(String id) => WordEntry(
  id: id,
  word: id,
  partOfSpeech: 'noun',
  phonetic: '',
  translationFr: 'mot',
  definitionEn: 'definition',
  example: 'example',
  bookId: 'book',
  chapterId: 'chapter',
);

SrsCard _card(String id, {required int reviews}) => SrsCard(
  entry: _entry(id),
  card: Card(cardId: srsCardIdFor(id), due: DateTime(2026, 11, 26)),
  introducedAt: DateTime(2026, 11, 20),
  reviews: reviews,
);

void main() {
  final now = DateTime(2026, 11, 26, 12);

  group('buildDashboardStats', () {
    test('additionne les minutes des 7 derniers jours seulement', () {
      final stats = buildDashboardStats(
        now: now,
        sessions: [
          ProgramSession(date: DateTime(2026, 11, 26), minutes: 8),
          ProgramSession(date: DateTime(2026, 11, 25), minutes: 6),
          ProgramSession(date: DateTime(2026, 11, 20), minutes: 10),
          ProgramSession(date: DateTime(2026, 11, 19), minutes: 40),
        ],
        cards: const [],
        events: const [],
        streak: 4,
      );

      expect(stats.minutesLast7Days, 24);
      expect(stats.streak, 4);
      expect(stats.activity, isEmpty);
    });

    test('compte les chapitres distincts terminés', () {
      final stats = buildDashboardStats(
        now: now,
        sessions: const [],
        cards: const [],
        events: [
          TelemetryEvent(
            name: 'chapter_completed',
            at: now,
            properties: const {'chapterId': 'a'},
          ),
          TelemetryEvent(
            name: 'chapter_completed',
            at: now,
            properties: const {'chapterId': 'a'},
          ),
          TelemetryEvent(
            name: 'chapter_completed',
            at: now,
            properties: const {'chapterId': 'b'},
          ),
          TelemetryEvent(
            name: 'chapter_started',
            at: now,
            properties: const {'chapterId': 'c'},
          ),
        ],
        streak: 0,
      );

      expect(stats.chaptersCompleted, 2);
    });

    test('un chapitre sans identifiant est compté par son numéro', () {
      final stats = buildDashboardStats(
        now: now,
        sessions: const [],
        cards: const [],
        events: [
          TelemetryEvent(
            name: 'chapter_completed',
            at: now,
            properties: const {'chapterNumber': 3},
          ),
          TelemetryEvent(
            name: 'chapter_completed',
            at: now,
            properties: const {'chapterNumber': 3},
          ),
        ],
        streak: 0,
      );

      expect(stats.chaptersCompleted, 1);
    });

    test('maîtrise à partir de trois révisions', () {
      final stats = buildDashboardStats(
        now: now,
        sessions: const [],
        cards: [
          _card('one', reviews: 1),
          _card('three', reviews: 3),
          _card('five', reviews: 5),
        ],
        events: const [],
        streak: 0,
      );

      expect(stats.wordsMastered, 2);
    });

    test('activité limitée aux 8 derniers événements suivis', () {
      final events = [
        for (var i = 0; i < 12; i++)
          TelemetryEvent(
            name: i.isEven ? 'chapter_completed' : 'review_completed',
            at: now.subtract(Duration(hours: i)),
            properties: i.isEven
                ? const {'chapterNumber': 2, 'minutes': 7}
                : const {'reviewed': 4},
          ),
        TelemetryEvent(
          name: 'app_opened',
          at: now.add(const Duration(minutes: 1)),
        ),
      ];

      final stats = buildDashboardStats(
        now: now,
        sessions: const [],
        cards: const [],
        events: events,
        streak: 0,
      );

      expect(stats.activity, hasLength(8));
      expect(stats.activity.first.at, now.subtract(const Duration(hours: 11)));
      expect(stats.activity.last.at, now.subtract(const Duration(hours: 4)));
      expect(stats.activity.first.title, 'Révision terminée');
      expect(stats.activity.first.detail, '4 cartes révisées');
      expect(stats.activity[1].title, 'Chapitre 2 terminé');
      expect(stats.activity[1].detail, '7 min de lecture');
    });
  });

  group('formatRelativeActivity', () {
    test('couvre instant, minutes, heures, hier, jours et date', () {
      expect(
        formatRelativeActivity(now.subtract(const Duration(seconds: 20)), now),
        'À l’instant',
      );
      expect(
        formatRelativeActivity(now.subtract(const Duration(minutes: 12)), now),
        'il y a 12 min',
      );
      expect(
        formatRelativeActivity(now.subtract(const Duration(hours: 5)), now),
        'il y a 5 h',
      );
      expect(formatRelativeActivity(DateTime(2026, 11, 25, 20), now), 'hier');
      expect(
        formatRelativeActivity(DateTime(2026, 11, 22, 20), now),
        'il y a 4 j',
      );
      expect(
        formatRelativeActivity(DateTime(2026, 11, 2, 20), now),
        'le 02/11',
      );
    });

    test('une date future reste affichée comme instantanée', () {
      expect(
        formatRelativeActivity(now.add(const Duration(minutes: 5)), now),
        'À l’instant',
      );
    });
  });
}
