import 'dart:convert';

import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/account/presentation/auth_provider.dart';
import 'package:storylingo/features/program/data/program_repository.dart';
import 'package:storylingo/features/program/domain/program_session.dart';
import 'package:storylingo/features/program/presentation/program_provider.dart';
import 'package:storylingo/features/progress/presentation/progress_screen.dart';
import 'package:storylingo/features/reading/data/reading_progress_repository.dart';
import 'package:storylingo/features/reading/presentation/reading_progress_provider.dart';
import 'package:storylingo/features/reading/presentation/reading_screen.dart';
import 'package:storylingo/features/telemetry/data/telemetry_repository.dart';
import 'package:storylingo/features/telemetry/presentation/telemetry_provider.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/domain/srs_card.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

import 'support/in_memory_token_store.dart';

WordEntry _entry(String word) {
  return WordEntry(
    id: 'sleepy-hollow/$word',
    word: word,
    partOfSpeech: 'noun',
    phonetic: '/$word/',
    definitionEn: 'definition of $word',
    translationFr: 'traduction',
    example: 'An example with $word.',
    bookId: 'sleepy-hollow',
    chapterId: 'chapter-01',
  );
}

SrsCard _card(String word, {int reviews = 0}) {
  return SrsCard(
    entry: _entry(word),
    card: fsrs.Card(
      cardId: srsCardIdFor('sleepy-hollow/$word'),
      due: DateTime.utc(2026, 11, 22, 8),
      lastReview: reviews == 0 ? null : DateTime.utc(2026, 11, 21, 8),
    ),
    introducedAt: DateTime.utc(2026, 11, 20, 8),
    firstReviewedAt: reviews == 0 ? null : DateTime.utc(2026, 11, 21, 8),
    lastReviewedAt: reviews == 0 ? null : DateTime.utc(2026, 11, 21, 8),
    reviews: reviews,
  );
}

ProgramSession _session(int day, {int minutes = 10}) =>
    ProgramSession(date: DateTime(2026, 11, day), minutes: minutes);

Future<Widget> _buildApp({
  List<ProgramSession> sessions = const [],
  List<SrsCard> cards = const [],
  DateTime? now,
  Map<String, Object> extraValues = const {},
}) async {
  final clock = now ?? DateTime(2026, 11, 22, 10);
  SharedPreferences.setMockInitialValues({
    PrefsKeys.onboardingCompleted: true,
    PrefsKeys.userLevel: 'b1',
    PrefsKeys.userInterests: <String>['mystery', 'gothic'],
    if (sessions.isNotEmpty)
      PrefsKeys.programSessions: <String>[
        for (final session in sessions) jsonEncode(session.toJson()),
      ],
    if (cards.isNotEmpty)
      PrefsKeys.srsCards: <String>[
        for (final card in cards) jsonEncode(card.toJson()),
      ],
    ...extraValues,
  });
  final sharedPreferences = await SharedPreferences.getInstance();
  final repository = PrefsRepository(sharedPreferences);
  await repository.ensureSchemaVersion();

  return ProviderScope(
    overrides: [
      prefsRepositoryProvider.overrideWithValue(repository),
      readingProgressRepositoryProvider.overrideWithValue(
        ReadingProgressRepository(sharedPreferences),
      ),
      savedWordsRepositoryProvider.overrideWithValue(
        SavedWordsRepository(sharedPreferences),
      ),
      srsRepositoryProvider.overrideWithValue(SrsRepository(sharedPreferences)),
      programRepositoryProvider.overrideWithValue(
        ProgramRepository(sharedPreferences),
      ),
      telemetryRepositoryProvider.overrideWithValue(
        TelemetryRepository(sharedPreferences),
      ),
      nowProvider.overrideWithValue(() => clock),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: const StorylingoApp(),
  );
}

Future<void> _openProgress(WidgetTester tester) async {
  await tester.tap(find.text('Progrès'));
  await tester.pumpAndSettle();
}

Future<void> _finishChapter(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Terminer le chapitre'),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Terminer le chapitre'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Terminer le chapitre'));
  await tester.pumpAndSettle();
}

Future<void> _returnToPath(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byType(ReadingScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text('Retour au parcours'),
    200,
    scrollable: scrollable,
  );
  await tester.ensureVisible(find.text('Retour au parcours'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Retour au parcours'));
  await tester.pumpAndSettle();
}

Finder _statValue(String label, String value) {
  final card = find.widgetWithText(Card, label);
  return find.descendant(of: card, matching: find.text(value));
}

Finder _badgeIcon(String title, IconData icon) {
  final card = find.widgetWithText(Card, title);
  return find.descendant(of: card, matching: find.byIcon(icon));
}

Future<List<Map<String, dynamic>>> _telemetryEvents(
  SharedPreferences prefs,
) async {
  return [
    for (final raw
        in prefs.getStringList(PrefsKeys.telemetryEvents) ?? const <String>[])
      jsonDecode(raw) as Map<String, dynamic>,
  ];
}

Future<void> _scrollSettingsTo(WidgetTester tester, String label) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(find.text(label), 250, scrollable: scrollable);
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _scrollProgressTo(WidgetTester tester, String label) async {
  final scrollable = find
      .descendant(
        of: find.byType(ProgressScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: scrollable,
  );
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Today shows the program day and opens its chapter', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Jour 1 sur 28'), findsOneWidget);
    expect(find.text('Chapitre 1 · révision de vos mots'), findsOneWidget);
    expect(find.text('≈ 9 min · lecture + révision'), findsOneWidget);
    expect(find.text('À faire aujourd’hui'), findsOneWidget);
    expect(find.text('0 j'), findsOneWidget);
    expect(find.text('Commencer la session'), findsOneWidget);

    await tester.tap(find.text('Commencer la session'));
    await tester.pumpAndSettle();

    expect(find.byType(ReadingScreen), findsOneWidget);
  });

  testWidgets('Today offers to resume a chapter in progress', (tester) async {
    await tester.pumpWidget(
      await _buildApp(
        extraValues: {
          PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01'):
              'paragraph-02',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reprendre le chapitre 1'), findsOneWidget);
    expect(find.text('Commencer la session'), findsNothing);
  });

  testWidgets('finishing a chapter records the day and the streak', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Commencer la session'));
    await tester.pumpAndSettle();
    await _finishChapter(tester);
    await _returnToPath(tester);

    expect(find.text('Objectif du jour terminé'), findsOneWidget);
    expect(find.text('Relire le chapitre 1'), findsOneWidget);
    expect(find.text('1 j'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final rawSessions = prefs.getStringList(PrefsKeys.programSessions);
    expect(rawSessions, hasLength(1));
    final session = ProgramSession.fromJson(jsonDecode(rawSessions!.single));
    expect(session!.date, DateTime(2026, 11, 22));
    expect(session.minutes, 1);

    await _openProgress(tester);

    expect(find.text('1 jour sur 28'), findsOneWidget);
    expect(find.text('Série : 1 j'), findsOneWidget);
    expect(find.text('Bouclier disponible'), findsOneWidget);

    await _scrollProgressTo(tester, 'Révisions');
    expect(_statValue('Minutes lues', '1 min'), findsOneWidget);

    await _scrollProgressTo(tester, 'Premier pas');
    expect(_badgeIcon('Premier pas', Icons.check_circle), findsOneWidget);
    await _scrollProgressTo(tester, 'Mi-parcours');
    expect(_badgeIcon('Mi-parcours', Icons.lock_outline), findsOneWidget);
  });

  testWidgets('Progress reflects a protected streak, stats and badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(
        sessions: [
          _session(19, minutes: 12),
          _session(20, minutes: 8),
          _session(22, minutes: 9),
        ],
        cards: [
          _card('mist', reviews: 60),
          _card('porch', reviews: 30),
          _card('whisper', reviews: 10),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jour 3 sur 28'), findsOneWidget);
    expect(find.text('Objectif du jour terminé'), findsOneWidget);
    expect(find.text('3 j'), findsOneWidget);

    await _openProgress(tester);

    expect(find.text('3 jours sur 28'), findsOneWidget);
    expect(find.text('Série : 3 j'), findsOneWidget);
    expect(find.text('Bouclier utilisé'), findsOneWidget);
    expect(find.text('Record : 3 j'), findsOneWidget);

    await _scrollProgressTo(tester, 'Révisions');
    expect(_statValue('Minutes lues', '29 min'), findsOneWidget);
    expect(_statValue('Mots en révision', '3'), findsOneWidget);
    expect(_statValue('Révisions', '100'), findsOneWidget);

    await _scrollProgressTo(tester, 'Série de 3 jours');
    expect(_badgeIcon('Série de 3 jours', Icons.check_circle), findsOneWidget);
    await _scrollProgressTo(tester, 'Mi-parcours');
    expect(_badgeIcon('Mi-parcours', Icons.lock_outline), findsOneWidget);
  });

  testWidgets('a completed program stays visible and playable', (tester) async {
    final sessions = [
      for (var index = 0; index < 28; index++)
        ProgramSession(
          date: DateTime(2026, 10, 25).add(Duration(days: index)),
          minutes: 10,
        ),
    ];
    await tester.pumpWidget(await _buildApp(sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.text('Parcours terminé'), findsOneWidget);
    expect(
      find.text('Programme accompli — entraînement libre'),
      findsOneWidget,
    );
    expect(find.text('Relire le chapitre 1'), findsOneWidget);

    await _openProgress(tester);

    final inProgress = find.descendant(
      of: find.byType(ProgressScreen),
      matching: find.text('Parcours terminé'),
    );
    expect(inProgress, findsOneWidget);
    expect(find.text('28 jours sur 28'), findsOneWidget);

    await _scrollProgressTo(tester, 'Les 28 jours');
    expect(_badgeIcon('Les 28 jours', Icons.check_circle), findsOneWidget);
    await _scrollProgressTo(tester, 'Dix mots en révision');
    expect(
      _badgeIcon('Dix mots en révision', Icons.lock_outline),
      findsOneWidget,
    );
  });

  testWidgets('finishing the pilot book closes the loop and logs events', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(
        sessions: [_session(20), _session(21)],
        extraValues: {
          PrefsKeys.readingCompleted('sleepy-hollow', 'chapter-01'): true,
          PrefsKeys.readingCompleted('sleepy-hollow', 'chapter-02'): true,
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jour 3 sur 28'), findsOneWidget);
    await tester.tap(find.text('Commencer la session'));
    await tester.pumpAndSettle();
    await _finishChapter(tester);

    expect(find.text('Jour 3 validé · série de 3 j'), findsOneWidget);
    expect(find.text('Vous avez terminé le livre pilote !'), findsOneWidget);
    expect(find.text('Votre révision du jour'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final events = await _telemetryEvents(prefs);
    final names = events.map((event) => event['name']).toList();
    expect(names, containsAll(['app_opened', 'chapter_started']));
    final completed = events.firstWhere(
      (event) => event['name'] == 'chapter_completed',
    );
    expect(completed['chapterId'], 'chapter-03');
    expect(completed['chapterNumber'], 3);
    expect(completed['minutes'], 1);
    expect(completed['newWords'], 8);
    expect(completed['programDay'], 3);
  });

  testWidgets('settings exports then clears the local telemetry', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(await _buildApp(sessions: [_session(22)]));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();

    await _scrollSettingsTo(tester, 'Copier l’export JSON');
    await tester.tap(find.text('Copier l’export JSON'));
    await tester.pumpAndSettle();

    expect(
      find.text('Export copié dans le presse-papiers.'),
      findsOneWidget,
    );
    expect(copied, isNotNull);
    final export = jsonDecode(copied!) as Map<String, dynamic>;
    expect(export['schemaVersion'], 1);
    expect(
      (export['participant'] as Map<String, dynamic>)['level'],
      'b1',
    );
    final content = export['content'] as Map<String, dynamic>;
    expect(content['packVersion'], '1.3.0');
    expect(content['chapters'], 3);
    expect(
      (export['program'] as Map<String, dynamic>)['currentDay'],
      1,
    );
    final exportedEvents = (export['events'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      exportedEvents.map((event) => event['name']),
      contains('app_opened'),
    );

    await _scrollSettingsTo(tester, 'Effacer la télémétrie');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Effacer la télémétrie'));
    await tester.pumpAndSettle();
    expect(find.text('Effacer la télémétrie ?'), findsOneWidget);
    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();

    expect(find.text('0 événements enregistrés'), findsOneWidget);
    expect(
      find.text('Télémétrie effacée.'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(PrefsKeys.telemetryEvents), isEmpty);
  });

  testWidgets('chapter recap fits a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer la session'));
    await tester.pumpAndSettle();
    await _finishChapter(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Jour 1 validé · série de 1 j'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Fermer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings fit a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await _buildApp(sessions: [_session(22)], cards: [_card('mist')]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    await _scrollSettingsTo(tester, 'Effacer la télémétrie');
    expect(tester.takeException(), isNull);
    expect(find.text('Copier l’export JSON'), findsOneWidget);
    expect(find.text('Effacer la télémétrie'), findsOneWidget);
  });

  testWidgets('Today and Progress fit a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      await _buildApp(
        sessions: [_session(20), _session(22)],
        cards: [for (var index = 0; index < 10; index++) _card('word$index')],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await _openProgress(tester);
    expect(tester.takeException(), isNull);

    final scrollable = find
        .descendant(
          of: find.byType(ProgressScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Dix mots en révision'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
