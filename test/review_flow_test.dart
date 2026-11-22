import 'dart:convert';

import 'package:fsrs/fsrs.dart' show Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide Card;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/program/data/program_repository.dart';
import 'package:storylingo/features/program/presentation/program_provider.dart';
import 'package:storylingo/features/reading/data/reading_progress_repository.dart';
import 'package:storylingo/features/reading/presentation/reading_progress_provider.dart';
import 'package:storylingo/features/reading/presentation/reading_screen.dart';
import 'package:storylingo/features/telemetry/data/telemetry_repository.dart';
import 'package:storylingo/features/telemetry/presentation/telemetry_provider.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/domain/srs_card.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/presentation/pronunciation_providers.dart';
import 'package:storylingo/features/vocabulary/presentation/review_screen.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

import 'support/fake_word_pronouncer.dart';

WordEntry _entry(
  String word, {
  String translation = 'traduction',
  PronunciationClip? clip,
}) {
  return WordEntry(
    id: 'sleepy-hollow/$word',
    word: word,
    partOfSpeech: 'noun',
    phonetic: '/$word/',
    definitionEn: 'definition of $word',
    translationFr: translation,
    example: 'An example with $word.',
    bookId: 'sleepy-hollow',
    chapterId: 'chapter-01',
    clip: clip,
  );
}

SrsCard _card(
  String word, {
  DateTime? due,
  DateTime? lastReview,
  DateTime? firstReviewedAt,
  int reviews = 0,
  String translation = 'traduction',
  PronunciationClip? clip,
}) {
  return SrsCard(
    entry: _entry(word, translation: translation, clip: clip),
    card: Card(
      cardId: srsCardIdFor('sleepy-hollow/$word'),
      due: due,
      lastReview: lastReview,
    ),
    introducedAt: DateTime.utc(2026, 11, 22, 8),
    firstReviewedAt: firstReviewedAt,
    lastReviewedAt: lastReview,
    reviews: reviews,
  );
}

Future<Widget> _buildApp({
  List<SrsCard> cards = const [],
  Map<String, Object> extraValues = const {},
  FakeWordPronouncer? pronouncer,
}) async {
  SharedPreferences.setMockInitialValues({
    PrefsKeys.onboardingCompleted: true,
    PrefsKeys.userLevel: 'b1',
    PrefsKeys.userInterests: <String>['mystery', 'gothic'],
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
      wordPronouncerProvider.overrideWithValue(
        pronouncer ?? FakeWordPronouncer(),
      ),
    ],
    child: const StorylingoApp(),
  );
}

Finder _inReview(Finder finder) {
  return find.descendant(of: find.byType(ReviewScreen), matching: finder);
}

Future<void> _tapVisible(
  WidgetTester tester,
  String label, {
  Finder Function(Finder)? scope,
}) async {
  final finder = scope == null ? find.text(label) : scope(find.text(label));
  final scrollable = scope == null
      ? find.byType(Scrollable).first
      : find
            .descendant(
              of: find.byType(ReviewScreen),
              matching: find.byType(Scrollable),
            )
            .first;
  await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openReview(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    find.text('Réviser mes mots'),
    200,
    scrollable: scrollable,
  );
  await tester.ensureVisible(find.text('Réviser mes mots'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Réviser mes mots'));
  await tester.pumpAndSettle();
}

Future<void> _rate(WidgetTester tester, String label) async {
  await _tapVisible(tester, 'Afficher la réponse', scope: _inReview);
  await _tapVisible(tester, label, scope: _inReview);
}

void main() {
  testWidgets('Today announces the daily words and opens a full review', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(cards: [_card('mist', translation: 'la brume')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vos mots du jour'), findsOneWidget);
    expect(find.text('Nouveaux mots : 0/10'), findsOneWidget);
    expect(find.text('1 carte à réviser'), findsOneWidget);

    await _openReview(tester);

    expect(_inReview(find.text('Carte 1 sur 1')), findsOneWidget);
    expect(_inReview(find.text('mist')), findsOneWidget);
    expect(_inReview(find.text('la brume')), findsNothing);

    await _tapVisible(tester, 'Afficher la réponse', scope: _inReview);

    expect(_inReview(find.text('la brume')), findsOneWidget);
    expect(_inReview(find.text('Définition')), findsOneWidget);
    expect(_inReview(find.text('Comment était-ce ?')), findsOneWidget);
    expect(_inReview(find.text('À revoir')), findsOneWidget);
    expect(_inReview(find.text('Difficile')), findsOneWidget);
    expect(_inReview(find.text('Bien')), findsOneWidget);
    expect(_inReview(find.text('Facile')), findsOneWidget);

    await _tapVisible(tester, 'Bien', scope: _inReview);

    expect(find.text('Belle session !'), findsOneWidget);
    expect(find.text('1 mot revu'), findsOneWidget);
    expect(
      find.text('Vos mots sont à jour pour aujourd’hui.'),
      findsOneWidget,
    );

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(PrefsKeys.srsCards)!;
    final decoded = jsonDecode(stored.single) as Map<String, dynamic>;
    expect(decoded['reviews'], 1);
    expect(decoded['firstReviewedAt'], isNotNull);

    final events = [
      for (final raw
          in prefs.getStringList(PrefsKeys.telemetryEvents) ?? const <String>[])
        jsonDecode(raw) as Map<String, dynamic>,
    ];
    final names = events.map((event) => event['name']).toList();
    expect(names, containsAll(['app_opened', 'review_started']));
    final completed = events.firstWhere(
      (event) => event['name'] == 'review_completed',
    );
    expect(completed['reviewed'], 1);
    expect(completed['good'], 1);
    expect(completed['again'], 0);

    await tester.tap(find.text('Terminer la session'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.text('Vos mots du jour'), findsOneWidget);
  });

  testWidgets('an "Again" card comes back once in the same session', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(cards: [_card('mist'), _card('porch')]),
    );
    await tester.pumpAndSettle();
    await _openReview(tester);

    expect(_inReview(find.text('Carte 1 sur 2')), findsOneWidget);
    await _rate(tester, 'À revoir');

    expect(_inReview(find.text('Carte 2 sur 3')), findsOneWidget);
    await _rate(tester, 'Bien');

    expect(_inReview(find.text('Carte 3 sur 3')), findsOneWidget);
    expect(_inReview(find.text('mist')), findsOneWidget);
    await _rate(tester, 'Bien');

    expect(find.text('Belle session !'), findsOneWidget);
    expect(find.text('2 mots revus'), findsOneWidget);
    expect(find.text('1 mot à revoir bientôt.'), findsOneWidget);
  });

  testWidgets('the daily goal hides new cards once ten were studied', (
    tester,
  ) async {
    final today = DateTime.now();
    final studied = [
      for (var i = 0; i < 10; i++)
        _card(
          'word-$i',
          due: today.add(const Duration(days: 2)),
          lastReview: today,
          firstReviewedAt: today,
          reviews: 1,
        ),
    ];
    await tester.pumpWidget(
      await _buildApp(cards: [...studied, _card('fresh')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouveaux mots : 10/10'), findsOneWidget);
    expect(find.text('Tout est à jour.'), findsOneWidget);

    await _openReview(tester);

    expect(find.byType(ReviewScreen), findsNothing);
  });

  testWidgets('Écouter plays the pack clip and closing stops it', (
    tester,
  ) async {
    final pronouncer = FakeWordPronouncer();
    const clip = PronunciationClip(
      asset: 'assets/content/sleepy-hollow-a2/audio/chapter-01.mp3',
      start: Duration(milliseconds: 5788),
      end: Duration(milliseconds: 6162),
    );
    await tester.pumpWidget(
      await _buildApp(
        cards: [_card('mist', clip: clip)],
        pronouncer: pronouncer,
      ),
    );
    await tester.pumpAndSettle();
    await _openReview(tester);

    await tester.tap(_inReview(find.text('Écouter')));
    await tester.pumpAndSettle();

    expect(pronouncer.calls, hasLength(1));
    expect(pronouncer.calls.single.word, 'mist');
    final played = pronouncer.calls.single.clip!;
    expect(played.asset, clip.asset);
    expect(played.start, clip.start);
    expect(played.end, clip.end);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsNothing);
    expect(pronouncer.stopCalls, greaterThan(0));
  });

  testWidgets('an empty session explains how to get cards', (tester) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.text('Votre prochaine session')))
        .go('/review');
    await tester.pumpAndSettle();

    expect(find.text('Rien à réviser pour le moment'), findsOneWidget);
    expect(
      find.text('Terminez un chapitre pour ajouter ses mots à votre révision.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Votre prochaine session'), findsOneWidget);
  });

  testWidgets('the review fits a 360px-wide screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildApp(cards: [_card('reputation')]));
    await tester.pumpAndSettle();
    await _openReview(tester);

    expect(tester.takeException(), isNull);
    await _tapVisible(tester, 'Afficher la réponse', scope: _inReview);
    expect(tester.takeException(), isNull);
    expect(_inReview(find.text('Facile')), findsOneWidget);

    await _tapVisible(tester, 'Bien', scope: _inReview);
    expect(tester.takeException(), isNull);
    expect(find.text('Belle session !'), findsOneWidget);
    expect(find.text('Terminer la session'), findsOneWidget);
  });

  testWidgets('finishing a chapter adds its words and opens the review', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bibliothèque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lire le chapitre 1'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Terminer le chapitre'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Terminer le chapitre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer le chapitre'));
    await tester.pumpAndSettle();

    expect(find.text('Votre révision du jour'), findsOneWidget);
    expect(
      find.text('10 nouveaux mots ajoutés à votre révision.'),
      findsOneWidget,
    );
    expect(find.text('10 cartes prêtes à réviser.'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(PrefsKeys.srsCards), hasLength(10));

    final recapScrollable = find
        .descendant(
          of: find.byType(ReadingScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Réviser ces mots'),
      200,
      scrollable: recapScrollable,
    );
    await tester.ensureVisible(find.text('Réviser ces mots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réviser ces mots'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(find.text('Carte 1 sur 10'), findsOneWidget);
  });
}
