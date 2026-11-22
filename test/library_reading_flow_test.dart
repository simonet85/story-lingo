import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/content/data/content_repository.dart';
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

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw FlutterError('Missing asset: $key');
  }
}

Future<Widget> _buildApp({ContentRepository? contentRepository}) async {
  SharedPreferences.setMockInitialValues({
    PrefsKeys.onboardingCompleted: true,
    PrefsKeys.userLevel: 'b1',
    PrefsKeys.userInterests: <String>['mystery', 'adventure'],
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
      if (contentRepository != null)
        contentRepositoryProvider.overrideWithValue(contentRepository),
    ],
    child: const StorylingoApp(),
  );
}

Future<void> _openLibrary(WidgetTester tester) async {
  await tester.tap(find.text('Bibliothèque'));
  await tester.pumpAndSettle();
}

Future<void> _openChapter(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Lire le chapitre 1'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('library shows the pilot book and opens its chapter', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    await _openLibrary(tester);

    expect(find.text('The Legend of Sleepy Hollow'), findsOneWidget);
    expect(find.text('La Légende de Sleepy Hollow'), findsOneWidget);
    expect(find.text('Washington Irving'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
    expect(
      find.text('≈ 18 min · 56 mots nouveaux · 3 chapitres'),
      findsOneWidget,
    );

    await _openChapter(tester);

    expect(find.text('Lecture'), findsOneWidget);
    expect(find.text('A Quiet Valley'), findsOneWidget);
    expect(
      find.text(
        'Touchez un mot surligné pour voir sa définition et l’ajouter à '
        'votre liste.',
      ),
      findsOneWidget,
    );
    expect(find.text('≈ 6 min'), findsOneWidget);
    expect(
      find.textContaining('In the quiet valley of', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'like a horse walking in the dark',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Choisissez une histoire'), findsOneWidget);
    expect(find.text('Lire le chapitre 1'), findsOneWidget);
  });

  testWidgets('annotated segments are highlighted inside the paragraph', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await _openChapter(tester);

    final paragraphRichText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('paragraph-p-01')),
        matching: find.byType(RichText),
      ),
    );

    final highlighted = <TextSpan>[];
    void collect(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.style?.backgroundColor != null) highlighted.add(span);
      span.children?.forEach(collect);
    }

    collect(paragraphRichText.text);

    expect(highlighted, isNotEmpty);
    final annotated = highlighted.map((span) => span.text ?? '').join();
    expect(annotated, startsWith('Sleepy Hollow'));
  });

  testWidgets('library and reading screen fit a 360px-wide screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    expect(tester.takeException(), isNull);

    await _openChapter(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('A Quiet Valley'), findsOneWidget);
  });

  testWidgets('library shows a retry state when content cannot load', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _buildApp(
        contentRepository: ContentRepository(bundle: _MissingBundle()),
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    expect(find.text('Impossible de charger la bibliothèque.'), findsOneWidget);
    final retry = find.widgetWithText(FilledButton, 'Réessayer');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger la bibliothèque.'), findsOneWidget);
  });
}
