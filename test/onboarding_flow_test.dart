import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/features/account/presentation/auth_provider.dart';
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

import 'support/in_memory_token_store.dart';

Future<Widget> _buildApp(Map<String, Object> storedValues) async {
  SharedPreferences.setMockInitialValues(storedValues);
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
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: const StorylingoApp(),
  );
}

Future<void> _answerAllQuestions(WidgetTester tester) async {
  await tester.tap(find.text('Commencer'));
  await tester.pumpAndSettle();

  for (var index = 0; index < 10; index++) {
    await tester.tap(find.byKey(const ValueKey('answer-0')));
    await tester.pump();
    final label = index == 9 ? 'Voir mon niveau' : 'Suivant';
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('fresh start shows onboarding and completes to Today', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp({}));
    await tester.pumpAndSettle();

    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsNothing);

    await _answerAllQuestions(tester);
    expect(find.text('Votre niveau estimé'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuer'));
    await tester.pumpAndSettle();

    final continueButton = find.widgetWithText(FilledButton, 'Continuer');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.text('Policier & mystère'));
    await tester.tap(find.text('Gothique & horreur'));
    await tester.pump();

    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Aujourd’hui'), findsWidgets);
    expect(find.text('Commencer'), findsNothing);
  });

  testWidgets('completed onboarding boots into the shell with stored theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp({
        PrefsKeys.onboardingCompleted: true,
        PrefsKeys.userLevel: 'b1',
        PrefsKeys.userInterests: <String>['mystery', 'adventure'],
        PrefsKeys.themeMode: 'dark',
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aujourd’hui'), findsWidgets);
    expect(find.text('Commencer'), findsNothing);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
  });

  testWidgets('settings persist a level change', (tester) async {
    await tester.pumpWidget(
      await _buildApp({
        PrefsKeys.onboardingCompleted: true,
        PrefsKeys.userLevel: 'a2',
        PrefsKeys.userInterests: <String>['mystery', 'adventure'],
      }),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('B2'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('B2'));
    await tester.pumpAndSettle();

    final sharedPreferences = await SharedPreferences.getInstance();
    expect(sharedPreferences.getString(PrefsKeys.userLevel), 'b2');
  });
}
