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
import 'package:storylingo/features/reading/presentation/reading_progress_provider.dart';
import 'package:storylingo/features/telemetry/data/telemetry_repository.dart';
import 'package:storylingo/features/telemetry/presentation/telemetry_provider.dart';
import 'package:storylingo/features/vocabulary/data/saved_words_repository.dart';
import 'package:storylingo/features/vocabulary/data/srs_repository.dart';
import 'package:storylingo/features/vocabulary/presentation/saved_words_provider.dart';
import 'package:storylingo/features/vocabulary/presentation/srs_provider.dart';

Future<Widget> _buildApp({Map<String, Object> extraValues = const {}}) async {
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
    ],
    child: const StorylingoApp(),
  );
}

Future<void> _openLibrary(WidgetTester tester) async {
  await tester.tap(find.text('Bibliothèque'));
  await tester.pumpAndSettle();
}

Future<void> _openChapter(WidgetTester tester) async {
  await tester.tap(find.textContaining('le chapitre 1'));
  await tester.pumpAndSettle();
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('reading screen shows a session timer that counts down', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    final timerFinder = find.textContaining(RegExp(r'^\d{1,2}:\d{2}$'));
    expect(timerFinder, findsOneWidget);

    final initial = tester.widget<Text>(timerFinder).data!;
    expect(initial, matches(RegExp(r'^[56]:\d{2}$')));

    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Temps restant'), findsOneWidget);
    semantics.dispose();

    await tester.pump(const Duration(seconds: 1));

    final afterTick = tester.widget<Text>(timerFinder).data!;
    expect(afterTick, isNot(initial));

    await _disposeTree(tester);
  });

  testWidgets('reading screen restores the saved paragraph position', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(
        extraValues: {
          PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01'): 'p-04',
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(find.text('Reprise là où vous vous êtes arrêté.'), findsOneWidget);

    final restored = tester.getTopLeft(
      find.byKey(const ValueKey('paragraph-p-04')),
    );
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('paragraph-p-01')),
    );
    expect(restored.dy, lessThan(200));
    expect(first.dy, lessThan(0));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await _disposeTree(tester);
  });

  testWidgets('scrolling then leaving saves the reading position', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(
      PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01'),
    );
    expect(saved, isNotNull);
    expect(saved, isNot('p-01'));
    expect(find.text('Continuer le chapitre 1'), findsOneWidget);
  });

  testWidgets('finishing the chapter shows a recap and returns to Today', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    await tester.scrollUntilVisible(
      find.text('Terminer le chapitre'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Terminer le chapitre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer le chapitre'));
    await tester.pumpAndSettle();

    expect(find.text('Chapitre terminé'), findsOneWidget);
    expect(find.text('A Quiet Valley'), findsOneWidget);
    expect(find.text('Temps de lecture'), findsOneWidget);
    expect(find.text('Mots rencontrés'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Retour au parcours'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(PrefsKeys.readingCompleted('sleepy-hollow', 'chapter-01')),
      isTrue,
    );
    expect(
      prefs.getString(PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01')),
      isNull,
    );

    await tester.scrollUntilVisible(
      find.text('Retour au parcours'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Retour au parcours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retour au parcours'));
    await tester.pumpAndSettle();

    expect(find.text('Votre prochaine session'), findsOneWidget);
  });

  testWidgets('a finished chapter restarts from the beginning', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(
        extraValues: {
          PrefsKeys.readingCompleted('sleepy-hollow', 'chapter-01'): true,
          PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01'): 'p-04',
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    expect(find.text('Reprise là où vous vous êtes arrêté.'), findsNothing);
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('paragraph-p-01')),
    );
    expect(first.dy, greaterThan(0));

    await _disposeTree(tester);
  });

  testWidgets('library offers to continue a chapter in progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(
        extraValues: {
          PrefsKeys.readingPosition('sleepy-hollow', 'chapter-01'): 'p-03',
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    expect(find.text('Continuer le chapitre 1'), findsOneWidget);
    expect(find.text('Lire le chapitre 1'), findsNothing);
  });

  testWidgets('library offers to reread a finished chapter', (tester) async {
    await tester.pumpWidget(
      await _buildApp(
        extraValues: {
          PrefsKeys.readingCompleted('sleepy-hollow', 'chapter-01'): true,
        },
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    expect(find.text('Relire le chapitre 1'), findsOneWidget);
  });
}
