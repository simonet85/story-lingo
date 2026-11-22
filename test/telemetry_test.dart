import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';
import 'package:storylingo/features/onboarding/domain/user_prefs.dart';
import 'package:storylingo/features/program/domain/program_progress.dart';
import 'package:storylingo/features/program/domain/program_session.dart';
import 'package:storylingo/features/telemetry/data/telemetry_repository.dart';
import 'package:storylingo/features/telemetry/domain/telemetry_event.dart';
import 'package:storylingo/features/telemetry/domain/telemetry_export.dart';
import 'package:storylingo/features/telemetry/presentation/telemetry_provider.dart';
import 'package:storylingo/features/vocabulary/domain/srs_card.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

TelemetryEvent _event(int index) => TelemetryEvent(
  name: 'chapter_started',
  at: DateTime.utc(2026, 11, 20, 8).add(Duration(minutes: index)),
  properties: {'chapterNumber': index},
);

SrsCard _card(String word, {int reviews = 0, DateTime? firstReviewedAt}) {
  return SrsCard(
    entry: WordEntry(
      id: 'sleepy-hollow/$word',
      word: word,
      partOfSpeech: 'noun',
      phonetic: '/$word/',
      definitionEn: 'definition',
      translationFr: 'traduction',
      example: 'Example.',
      bookId: 'sleepy-hollow',
      chapterId: 'chapter-01',
    ),
    card: fsrs.Card(
      cardId: srsCardIdFor('sleepy-hollow/$word'),
      due: DateTime.utc(2026, 11, 22, 8),
      lastReview: reviews == 0 ? null : DateTime.utc(2026, 11, 21, 8),
    ),
    introducedAt: DateTime.utc(2026, 11, 20, 8),
    firstReviewedAt: firstReviewedAt,
    lastReviewedAt: reviews == 0 ? null : DateTime.utc(2026, 11, 21, 8),
    reviews: reviews,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TelemetryEvent round-trips its primitives', () {
    final event = TelemetryEvent(
      name: 'chapter_completed',
      at: DateTime.utc(2026, 11, 22, 9, 30),
      properties: const {
        'chapterId': 'chapter-02',
        'minutes': 6,
        'firstReading': true,
        'note': null,
      },
    );

    final decoded = TelemetryEvent.fromJson(event.toJson())!;
    expect(decoded.name, 'chapter_completed');
    expect(decoded.at, DateTime.utc(2026, 11, 22, 9, 30));
    expect(decoded.properties['chapterId'], 'chapter-02');
    expect(decoded.properties['minutes'], 6);
    expect(decoded.properties['firstReading'], isTrue);
    expect(decoded.properties.containsKey('note'), isTrue);
    expect(decoded.properties['note'], isNull);
  });

  test('TelemetryEvent rejects invalid entries and nested values', () {
    expect(TelemetryEvent.fromJson(null), isNull);
    expect(TelemetryEvent.fromJson({'at': '2026-11-22T09:00:00Z'}), isNull);
    expect(TelemetryEvent.fromJson({'name': '', 'at': 'bad'}), isNull);
    expect(TelemetryEvent.fromJson({'name': 'x', 'at': 'not-a-date'}), isNull);

    final event = TelemetryEvent.fromJson({
      'name': 'review_completed',
      'at': '2026-11-22T09:00:00Z',
      'reviewed': 4,
      'nested': {'a': 1},
      'list': [1, 2],
      'nameAgain': 'ignored',
    })!;
    expect(event.properties, {'reviewed': 4, 'nameAgain': 'ignored'});
  });

  test('sanitize keeps only primitives and protects reserved keys', () {
    final sanitized = sanitizeTelemetryProperties({
      'name': 'spoof',
      'at': 'spoof',
      'count': 3,
      'ratio': 0.5,
      'ok': false,
      'text': 'hello',
      'nested': {'x': 1},
      'list': ['x'],
    });
    expect(sanitized, {
      'count': 3,
      'ratio': 0.5,
      'ok': false,
      'text': 'hello',
    });
  });

  test('repository persists, tolerates and caps events', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = TelemetryRepository(prefs);

    await repository.save([_event(1), _event(2)]);
    final loaded = repository.load();
    expect(loaded, hasLength(2));
    expect(loaded.first.properties['chapterNumber'], 1);

    await prefs.setStringList(PrefsKeys.telemetryEvents, [
      jsonEncode(_event(3).toJson()),
      'not json',
      '{"name":"broken"}',
      jsonEncode(_event(4).toJson()),
    ]);
    final tolerant = repository.load();
    expect(tolerant, hasLength(2));
    expect(tolerant.last.properties['chapterNumber'], 4);

    await repository.save([for (var i = 0; i < 505; i++) _event(i)]);
    final capped = repository.load();
    expect(capped, hasLength(TelemetryRepository.maxEvents));
    expect(capped.first.properties['chapterNumber'], 5);
    expect(capped.last.properties['chapterNumber'], 504);
  });

  test('controller records with the injected clock and clears', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = TelemetryRepository(prefs);
    final clock = DateTime(2026, 11, 22, 10, 15);

    final container = ProviderContainer(
      overrides: [
        telemetryRepositoryProvider.overrideWithValue(repository),
        nowProvider.overrideWithValue(() => clock),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(telemetryProvider.notifier)
        .record(
          'app_opened',
          properties: {'level': 'b1', 'nested': <String, Object?>{'x': 1}},
        );
    final events = container.read(telemetryProvider);
    expect(events, hasLength(1));
    expect(events.single.name, 'app_opened');
    expect(events.single.at, clock.toUtc());
    expect(events.single.properties, {'level': 'b1'});

    final reopened = ProviderContainer(
      overrides: [telemetryRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(reopened.dispose);
    expect(reopened.read(telemetryProvider), hasLength(1));

    await reopened.read(telemetryProvider.notifier).clear();
    expect(reopened.read(telemetryProvider), isEmpty);
    expect(repository.load(), isEmpty);
  });

  test('export includes the pilot data without personal identifiers', () {
    final now = DateTime.utc(2026, 11, 22, 12);
    final progress = computeProgramProgress(
      [
        ProgramSession(date: DateTime(2026, 11, 21), minutes: 8),
        ProgramSession(date: DateTime(2026, 11, 20), minutes: 6),
      ],
      now: now,
    );
    final cards = [
      _card('mist', reviews: 2, firstReviewedAt: DateTime.utc(2026, 11, 21, 8)),
      _card('porch', reviews: 1, firstReviewedAt: DateTime.utc(2026, 11, 22, 12)),
      _card('ghost'),
    ];

    final exportedAt = now;
    final payload = buildTelemetryExport(
      events: [_event(1), _event(2)],
      sessions: [
        ProgramSession(date: DateTime(2026, 11, 21), minutes: 8),
        ProgramSession(date: DateTime(2026, 11, 20), minutes: 6),
      ],
      progress: progress,
      cards: cards,
      prefs: const UserPrefs(
        level: UserLevel.b1,
        interests: ['mystery'],
        onboardingCompleted: true,
        themeMode: ThemeMode.system,
      ),
      packVersion: '1.3.0',
      chapterCount: 3,
      exportedAt: exportedAt,
    );

    expect(payload['schemaVersion'], 1);
    expect(payload['exportedAt'], '2026-11-22T12:00:00.000Z');
    expect(payload['participant'], {
      'level': 'b1',
      'interests': ['mystery'],
    });
    expect(payload['content'], {'packVersion': '1.3.0', 'chapters': 3});
    expect(payload['vocabulary'], {
      'cards': 3,
      'reviews': 3,
      'newStudiedToday': 1,
      'dailyNewGoal': 10,
    });

    final program = payload['program']! as Map<String, Object?>;
    expect(program['daysCompleted'], 2);
    expect(program['currentDay'], 3);
    expect(program['doneToday'], isFalse);
    expect(program['streak'], 2);
    expect(program['sessions'], [
      {'date': '2026-11-20', 'minutes': 6},
      {'date': '2026-11-21', 'minutes': 8},
    ]);

    final events = payload['events']! as List<Object?>;
    expect(events, hasLength(2));
    expect((events.first! as Map)['name'], 'chapter_started');

    final encoded = encodeTelemetryExport(
      events: [_event(1), _event(2)],
      sessions: [ProgramSession(date: DateTime(2026, 11, 20), minutes: 6)],
      progress: progress,
      cards: cards,
      prefs: const UserPrefs(
        level: UserLevel.b1,
        interests: ['mystery'],
        onboardingCompleted: true,
        themeMode: ThemeMode.system,
      ),
      packVersion: '1.3.0',
      chapterCount: 3,
      exportedAt: exportedAt,
    );
    final decoded = jsonDecode(encoded) as Map<String, Object?>;
    expect(decoded['schemaVersion'], 1);
    expect(decoded['events'], hasLength(2));
    expect(encoded.contains('deviceId'), isFalse);
    expect(encoded.contains('email'), isFalse);
  });
}
