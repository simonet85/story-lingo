import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/program/data/program_repository.dart';
import 'package:storylingo/features/program/presentation/program_provider.dart';
import 'package:storylingo/features/reading/data/reading_progress_repository.dart';
import 'package:storylingo/features/reading/presentation/audio_providers.dart';
import 'package:storylingo/features/reading/presentation/reading_progress_provider.dart';
import 'package:storylingo/features/telemetry/data/telemetry_repository.dart';
import 'package:storylingo/features/telemetry/presentation/telemetry_provider.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/presentation/pronunciation_providers.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/word_sheet.dart';

import 'support/fake_audio_engine.dart';
import 'support/fake_word_pronouncer.dart';

class _Harness {
  final List<FakeAudioEngine> engines = [];
  final FakeWordPronouncer pronouncer = FakeWordPronouncer();

  FakeAudioEngine get engine => engines.single;

  FakeAudioEngine createEngine() {
    final engine = FakeAudioEngine();
    engines.add(engine);
    return engine;
  }
}

Future<Widget> _buildApp({
  required _Harness harness,
  Map<String, Object> extraValues = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    PrefsKeys.onboardingCompleted: true,
    PrefsKeys.userLevel: 'b1',
    PrefsKeys.userInterests: <String>['mystery', 'gothic'],
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
      audioEngineFactoryProvider.overrideWithValue(harness.createEngine),
      wordPronouncerProvider.overrideWithValue(harness.pronouncer),
    ],
    child: const StorylingoApp(),
  );
}

Future<void> _openLibrary(WidgetTester tester) async {
  await tester.tap(find.text('Bibliothèque'));
  await tester.pumpAndSettle();
}

Future<void> _openChapter(WidgetTester tester) async {
  await tester.tap(find.text('Lire le chapitre 1'));
  await tester.pumpAndSettle();
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

TextSpan _spanFromRichText(RichText richText, String text) {
  TextSpan? found;
  void visit(InlineSpan span) {
    if (span is! TextSpan) return;
    if (found == null && span.text == text) found = span;
    span.children?.forEach(visit);
  }

  visit(richText.text);
  expect(found, isNotNull, reason: 'No span "$text" in the paragraph.');
  return found!;
}

TextSpan _wordSpan(WidgetTester tester, String paragraphId, String text) {
  final richText = tester.widget<RichText>(
    find.descendant(
      of: find.byKey(ValueKey('paragraph-$paragraphId')),
      matching: find.byType(RichText),
    ),
  );
  return _spanFromRichText(richText, text);
}

Future<void> _tapWord(
  WidgetTester tester,
  String paragraphId,
  String text,
) async {
  final span = _wordSpan(tester, paragraphId, text);
  final recognizer = span.recognizer;
  expect(recognizer, isA<TapGestureRecognizer>());
  (recognizer! as TapGestureRecognizer).onTap!();
  await tester.pumpAndSettle();
}

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}

Map<String, Object?> _savedMistJson() {
  const entry = WordEntry(
    id: 'sleepy-hollow/mist',
    word: 'mist',
    partOfSpeech: 'noun',
    phonetic: '/mɪst/',
    definitionEn: 'thin fog close to the ground',
    translationFr: 'la brume',
    example: 'A cold mist covered the fields at dawn.',
    bookId: 'sleepy-hollow',
    chapterId: 'chapter-01',
  );
  return SavedWord(
    entry: entry,
    savedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  ).toJson();
}

void main() {
  testWidgets('tapping an annotated word opens its dictionary card', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    await _tapWord(tester, 'p-01', 'Mist');

    expect(find.text('mist'), findsOneWidget);
    expect(find.text('/mɪst/'), findsOneWidget);
    expect(find.text('nom'), findsOneWidget);
    expect(find.text('la brume'), findsOneWidget);
    expect(find.text('Définition'), findsOneWidget);
    expect(find.text('thin fog close to the ground'), findsOneWidget);
    expect(find.text('Exemple'), findsOneWidget);
    expect(
      find.text('“A cold mist covered the fields at dawn.”'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Écouter'), findsOneWidget);
    expect(find.text('Ajouter à ma liste de mots'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Écouter'));
    await tester.pumpAndSettle();

    final call = harness.pronouncer.calls.single;
    expect(call.word, 'mist');
    expect(call.clip, isNotNull);
    expect(
      call.clip!.asset,
      'assets/content/sleepy-hollow-a2/audio/chapter-01.mp3',
    );
    expect(call.clip!.start, const Duration(milliseconds: 5788));
    expect(call.clip!.end, const Duration(milliseconds: 6162));

    await _disposeTree(tester);
  });

  testWidgets('the multi-word entry plays the whole annotated group', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    await _tapWord(tester, 'p-01', 'Sleepy');

    expect(find.text('Sleepy Hollow'), findsOneWidget);
    expect(find.text('un vallon endormi'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Écouter'));
    await tester.pumpAndSettle();

    final call = harness.pronouncer.calls.single;
    expect(call.word, 'Sleepy Hollow');
    expect(call.clip!.start, const Duration(milliseconds: 1200));
    expect(call.clip!.end, const Duration(milliseconds: 1988));

    await _disposeTree(tester);
  });

  testWidgets('only annotated words expose a tap action', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(_wordSpan(tester, 'p-01', 'Mist').recognizer, isNotNull);
    expect(_wordSpan(tester, 'p-01', 'Sleepy').recognizer, isNotNull);
    expect(_wordSpan(tester, 'p-01', 'In').recognizer, isNull);
    expect(_wordSpan(tester, 'p-01', 'covered').recognizer, isNull);
    expect(_wordSpan(tester, 'p-01', '.').recognizer, isNull);

    await _disposeTree(tester);
  });

  testWidgets('adding and removing a word updates the list and preferences', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);
    await _tapWord(tester, 'p-01', 'Mist');

    await tester.tap(find.text('Ajouter à ma liste de mots'));
    await tester.pumpAndSettle();

    expect(find.text('Dans ma liste de mots'), findsOneWidget);
    expect(find.text('Ajouté à votre liste de mots.'), findsOneWidget);

    var prefs = await SharedPreferences.getInstance();
    var stored = prefs.getStringList(PrefsKeys.savedWords);
    expect(stored, hasLength(1));
    expect(stored!.single, contains('"id":"sleepy-hollow/mist"'));

    await tester.tap(find.text('Dans ma liste de mots'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter à ma liste de mots'), findsOneWidget);
    expect(find.text('Retiré de votre liste de mots.'), findsOneWidget);

    prefs = await SharedPreferences.getInstance();
    stored = prefs.getStringList(PrefsKeys.savedWords);
    expect(stored, isEmpty);

    await _disposeTree(tester);
  });

  testWidgets('the word list shows, reopens and removes a saved word', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);
    await _tapWord(tester, 'p-01', 'Mist');
    await tester.tap(find.text('Ajouter à ma liste de mots'));
    await tester.pumpAndSettle();
    await _closeSheet(tester);

    await tester.tap(find.byTooltip('Ma liste de mots'));
    await tester.pumpAndSettle();

    expect(find.text('1 mot'), findsOneWidget);
    expect(find.text('mist'), findsOneWidget);
    expect(find.text('la brume'), findsOneWidget);

    await tester.tap(find.text('mist'));
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsOneWidget);
    expect(find.text('Définition'), findsOneWidget);
    await _closeSheet(tester);

    await tester.tap(find.byTooltip('Retirer de la liste'));
    await tester.pumpAndSettle();

    expect(find.text('Votre liste est vide'), findsOneWidget);
    expect(find.text('Retiré de votre liste de mots.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(PrefsKeys.savedWords), isEmpty);

    await _disposeTree(tester);
  });

  testWidgets('the empty word list is reachable from the main tabs', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ma liste de mots'));
    await tester.pumpAndSettle();

    expect(find.text('Ma liste de mots'), findsOneWidget);
    expect(find.text('Votre liste est vide'), findsOneWidget);
    expect(
      find.text(
        'Touchez un mot surligné pendant votre lecture pour l’ajouter ici.',
      ),
      findsOneWidget,
    );

    await _disposeTree(tester);
  });

  testWidgets('a saved word is restored from preferences', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(
      await _buildApp(
        harness: harness,
        extraValues: {
          PrefsKeys.savedWords: <String>[jsonEncode(_savedMistJson())],
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ma liste de mots'));
    await tester.pumpAndSettle();

    expect(find.text('1 mot'), findsOneWidget);
    expect(find.text('mist'), findsOneWidget);
    expect(find.text('la brume'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('opening a word pauses the chapter narration', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    await tester.tap(find.text('Lire + Écouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lecture audio'));
    await tester.pump();
    harness.engine.emitPlaying(true);
    await tester.pumpAndSettle();

    await _tapWord(tester, 'p-01', 'Mist');

    expect(harness.engine.pauseCalls, greaterThan(0));
    expect(find.text('la brume'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('a failed pronunciation is reported inside the card', (
    tester,
  ) async {
    final harness = _Harness()..pronouncer.failAll = true;
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);
    await _tapWord(tester, 'p-01', 'Mist');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Écouter'));
    await tester.pumpAndSettle();

    expect(find.text('Prononciation indisponible.'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('the dictionary card fits a 360px-wide screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = _Harness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(tester.takeException(), isNull);

    await _tapWord(tester, 'p-01', 'Mist');

    expect(tester.takeException(), isNull);
    expect(find.text('la brume'), findsOneWidget);
    expect(find.text('Ajouter à ma liste de mots'), findsOneWidget);

    await _disposeTree(tester);
  });
}
