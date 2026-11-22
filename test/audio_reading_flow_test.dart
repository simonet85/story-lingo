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
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

import 'support/fake_audio_engine.dart';

class _AudioHarness {
  final List<FakeAudioEngine> engines = [];

  FakeAudioEngine get engine => engines.single;

  FakeAudioEngine create() {
    final engine = FakeAudioEngine();
    engines.add(engine);
    return engine;
  }
}

Future<Widget> _buildApp({
  required _AudioHarness harness,
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
      audioEngineFactoryProvider.overrideWithValue(harness.create),
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

List<String> _boldWords(WidgetTester tester, String paragraphId) {
  final richText = tester.widget<RichText>(
    find.descendant(
      of: find.byKey(ValueKey('paragraph-$paragraphId')),
      matching: find.byType(RichText),
    ),
  );

  final words = <String>[];
  void visit(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.style?.fontWeight == FontWeight.w700 && span.text != null) {
      words.add(span.text!);
    }
    span.children?.forEach(visit);
  }

  visit(richText.text);
  return words;
}

void main() {
  testWidgets('read mode never creates an audio engine', (tester) async {
    final harness = _AudioHarness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(find.text('Lire'), findsOneWidget);
    expect(find.text('Écouter'), findsOneWidget);
    expect(find.text('Lire + Écouter'), findsOneWidget);
    expect(find.text('−15 s'), findsNothing);
    expect(find.byTooltip('Lecture audio'), findsNothing);
    expect(harness.engines, isEmpty);
    expect(_boldWords(tester, 'p-01'), isEmpty);

    await _disposeTree(tester);
  });

  testWidgets('read + listen loads the track and highlights the first word', (
    tester,
  ) async {
    final harness = _AudioHarness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    await tester.tap(find.text('Lire + Écouter'));
    await tester.pumpAndSettle();

    expect(harness.engines, hasLength(1));
    expect(harness.engine.loadedAssets, hasLength(1));
    expect(find.text('−15 s'), findsOneWidget);
    expect(find.text('+15 s'), findsOneWidget);
    expect(find.byTooltip('Lecture audio'), findsOneWidget);
    expect(_boldWords(tester, 'p-01'), ['In']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsKeys.readingMode), 'read_listen');

    await _disposeTree(tester);
  });

  testWidgets('playing advances the karaoke and seeks by 15 seconds', (
    tester,
  ) async {
    final harness = _AudioHarness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);
    await tester.tap(find.text('Lire + Écouter'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lecture audio'));
    await tester.pump();
    expect(harness.engine.playCalls, 1);

    harness.engine.emitPlaying(true);
    harness.engine.emitPosition(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Pause audio'), findsOneWidget);
    expect(_boldWords(tester, 'p-01'), ['quiet']);

    await tester.tap(find.text('−15 s'));
    await tester.pumpAndSettle();
    expect(harness.engine.seeks.last, Duration.zero);

    await tester.tap(find.text('+15 s'));
    await tester.pumpAndSettle();
    expect(harness.engine.seeks.last, const Duration(milliseconds: 15000));
    expect(find.text('0:15'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('speed changes are applied and persisted', (tester) async {
    final harness = _AudioHarness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);
    await tester.tap(find.text('Lire + Écouter'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1.0×'));
    await tester.pumpAndSettle();
    expect(find.text('Vitesse de lecture'), findsOneWidget);

    await tester.tap(find.text('1.5× — Rapide'));
    await tester.pumpAndSettle();

    expect(find.text('1.5×'), findsOneWidget);
    expect(harness.engine.speeds.last, 1.5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(PrefsKeys.audioSpeed), 1.5);

    await _disposeTree(tester);
  });

  testWidgets('a saved speed is restored when audio mode opens', (
    tester,
  ) async {
    final harness = _AudioHarness();
    await tester.pumpWidget(
      await _buildApp(
        harness: harness,
        extraValues: {
          PrefsKeys.readingMode: 'read_listen',
          PrefsKeys.audioSpeed: 1.25,
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(find.text('1.25×'), findsOneWidget);
    expect(harness.engine.speeds, [1.25]);

    await _disposeTree(tester);
  });

  testWidgets('listen mode hides the text and shows the full panel', (
    tester,
  ) async {
    final harness = _AudioHarness();
    await tester.pumpWidget(
      await _buildApp(
        harness: harness,
        extraValues: {PrefsKeys.readingMode: 'listen'},
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(find.text('Écouter le chapitre'), findsOneWidget);
    expect(find.byTooltip('Lecture audio'), findsOneWidget);
    expect(find.text('−15 s'), findsOneWidget);
    expect(find.text('+15 s'), findsOneWidget);
    expect(find.byKey(const ValueKey('paragraph-p-01')), findsNothing);
    expect(find.text('Terminer le chapitre'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('switching back to read pauses the audio and removes karaoke', (
    tester,
  ) async {
    final harness = _AudioHarness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);
    await tester.tap(find.text('Lire + Écouter'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lecture audio'));
    harness.engine.emitPlaying(true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lire'));
    await tester.pumpAndSettle();

    expect(harness.engine.pauseCalls, greaterThan(0));
    expect(find.text('−15 s'), findsNothing);
    expect(_boldWords(tester, 'p-01'), isEmpty);

    await _disposeTree(tester);
  });

  testWidgets('audio reading fits a 360px-wide screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = _AudioHarness();
    await tester.pumpWidget(await _buildApp(harness: harness));
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Lire + Écouter'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('−15 s'), findsOneWidget);

    await _disposeTree(tester);
  });
}
