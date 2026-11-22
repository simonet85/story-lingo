import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/app.dart';
import 'package:storylingo/core/prefs/prefs_keys.dart';
import 'package:storylingo/core/prefs/prefs_repository.dart';
import 'package:storylingo/core/prefs/user_prefs_provider.dart';
import 'package:storylingo/features/content/data/catalogue_repository.dart';
import 'package:storylingo/features/content/data/content_repository.dart';
import 'package:storylingo/features/library/presentation/catalogue_book_card.dart';
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

const String _baseUrl = 'http://content.test';

Map<String, dynamic> _pilotCatalogueEntry() => {
  'id': 'sleepy-hollow',
  'title': 'The Legend of Sleepy Hollow',
  'titleFr': 'La Légende de Sleepy Hollow',
  'author': 'Washington Irving',
  'level': 'a2',
  'descriptionFr': 'Une vallée paisible que l’on dit hantée.',
  'packVersion': '1.3.0',
  'chapterCount': 3,
  'totalMinutes': 18,
  'newWordCount': 56,
  'isFree': true,
  'manifestUrl': '/v1/books/sleepy-hollow',
};

Map<String, dynamic> _remoteCatalogueEntry() => {
  'id': 'night-train',
  'title': 'The Night Train',
  'titleFr': 'Le Train de Nuit',
  'author': 'Ada Marchand',
  'level': 'b1',
  'descriptionFr': 'Un voyage qui ne devait jamais finir.',
  'packVersion': '2.0.0',
  'chapterCount': 1,
  'totalMinutes': 5,
  'newWordCount': 1,
  'isFree': true,
  'manifestUrl': '/v1/books/night-train',
};

Map<String, dynamic> _catalogueJson() => {
  'updatedAt': '2026-11-22T10:00:00Z',
  'books': <Map<String, dynamic>>[
    _remoteCatalogueEntry(),
    _pilotCatalogueEntry(),
  ],
};

Map<String, dynamic> _remoteManifestJson() => {
  'schemaVersion': 1,
  'packVersion': '2.0.0',
  'id': 'night-train',
  'title': 'The Night Train',
  'titleFr': 'Le Train de Nuit',
  'author': 'Ada Marchand',
  'level': 'b1',
  'descriptionFr': 'Un voyage qui ne devait jamais finir.',
  'chapters': <Map<String, dynamic>>[
    {
      'id': 'chapter-01',
      'number': 1,
      'title': 'Le Départ',
      'url': '/v1/books/night-train/chapters/chapter-01',
      'estimatedMinutes': 5,
      'newWordCount': 1,
    },
  ],
};

Map<String, dynamic> _remoteChapterJson() => {
  'schemaVersion': 2,
  'id': 'chapter-01',
  'bookId': 'night-train',
  'number': 1,
  'title': 'Le Départ',
  'level': 'b1',
  'paragraphs': <Map<String, dynamic>>[
    {
      'id': 'p-01',
      'segments': <Map<String, dynamic>>[
        {'text': 'The '},
        {'text': 'mist', 'vocabId': 'mist'},
        {'text': ' covered the fields.'},
      ],
    },
  ],
  'vocabulary': <Map<String, dynamic>>[
    {
      'id': 'mist',
      'word': 'mist',
      'partOfSpeech': 'noun',
      'phonetic': '/mɪst/',
      'definitionEn': 'thin fog close to the ground',
      'translationFr': 'la brume',
      'example': 'The mist covered the fields.',
      'cefr': 'a2',
    },
  ],
  'audio': <String, dynamic>{
    'url': '/v1/books/night-train/audio/chapter-01.mp3',
    'durationMs': 2000,
    'voice': 'en-US-AriaNeural',
    'words': <Map<String, dynamic>>[
      {'text': 'The', 'startMs': 0, 'endMs': 200},
      {'text': 'mist', 'startMs': 200, 'endMs': 500},
      {'text': 'covered', 'startMs': 500, 'endMs': 900},
      {'text': 'the', 'startMs': 900, 'endMs': 1100},
      {'text': 'fields', 'startMs': 1100, 'endMs': 1600},
    ],
  },
};

http.Response _jsonResponse(Object? payload) {
  return http.Response.bytes(utf8.encode(jsonEncode(payload)), 200);
}

class _ContentServer {
  bool offline = false;

  late final http.Client client = MockClient((request) async {
    if (offline) throw http.ClientException('offline', request.url);
    switch (request.url.path) {
      case '/v1/catalogue':
        return _jsonResponse(_catalogueJson());
      case '/v1/books/night-train':
        return _jsonResponse(_remoteManifestJson());
      case '/v1/books/night-train/chapters/chapter-01':
        return _jsonResponse(_remoteChapterJson());
    }
    return http.Response('{"detail": "not found"}', 404);
  });
}

class _Harness {
  _Harness(this.server, {bool offline = false}) {
    server.offline = offline || server.offline;
  }

  final _ContentServer server;
  final List<FakeAudioEngine> engines = [];

  FakeAudioEngine createEngine() {
    final engine = FakeAudioEngine();
    engines.add(engine);
    return engine;
  }
}

Future<Widget> _buildApp({
  required SharedPreferences sharedPreferences,
  required CatalogueRepository repository,
  required _Harness harness,
}) async {
  final prefs = PrefsRepository(sharedPreferences);
  await prefs.ensureSchemaVersion();

  return ProviderScope(
    overrides: [
      prefsRepositoryProvider.overrideWithValue(prefs),
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
      catalogueRepositoryProvider.overrideWithValue(repository),
      audioEngineFactoryProvider.overrideWithValue(harness.createEngine),
    ],
    child: const StorylingoApp(),
  );
}

Future<SharedPreferences> _prefsWith([Map<String, Object> extra = const {}]) {
  SharedPreferences.setMockInitialValues({
    PrefsKeys.onboardingCompleted: true,
    PrefsKeys.userLevel: 'b1',
    PrefsKeys.userInterests: <String>['mystery', 'adventure'],
    ...extra,
  });
  return SharedPreferences.getInstance();
}

CatalogueRepository _repository(
  _ContentServer server,
  SharedPreferences sharedPreferences,
) {
  return CatalogueRepository(
    baseUrl: _baseUrl,
    preferences: sharedPreferences,
    client: server.client,
  );
}

Future<void> _openLibrary(WidgetTester tester) async {
  await tester.tap(find.text('Bibliothèque'));
  await tester.pumpAndSettle();
}

Finder _remoteCta(String label) {
  return find.descendant(
    of: find.byType(CatalogueBookCard),
    matching: find.text(label),
  );
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('library merges the remote catalogue with the embedded pilot', (
    tester,
  ) async {
    final server = _ContentServer();
    final sharedPreferences = await _prefsWith();
    final harness = _Harness(server);
    await tester.pumpWidget(
      await _buildApp(
        sharedPreferences: sharedPreferences,
        repository: _repository(server, sharedPreferences),
        harness: harness,
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    expect(find.text('Le Train de Nuit'), findsOneWidget);
    expect(find.text('La Légende de Sleepy Hollow'), findsOneWidget);
    expect(find.text('Ada Marchand'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(
      find.text('≈ 5 min · 1 mots nouveaux · 1 chapitre'),
      findsOneWidget,
    );
    expect(_remoteCta('Lire le chapitre 1'), findsOneWidget);

    final remoteTop = tester.getTopLeft(find.text('Le Train de Nuit')).dy;
    final pilotTop = tester
        .getTopLeft(find.text('La Légende de Sleepy Hollow'))
        .dy;
    expect(remoteTop, lessThan(pilotTop));

    await tester.tap(_remoteCta('Lire le chapitre 1'));
    await tester.pumpAndSettle();

    expect(find.text('Lecture'), findsOneWidget);
    expect(find.text('Le Départ'), findsOneWidget);
    expect(
      find.textContaining('The mist covered the fields.', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Lire + Écouter'));
    await tester.pumpAndSettle();

    expect(harness.engines.single.loadedUrls, [
      'http://content.test/v1/books/night-train/audio/chapter-01.mp3',
    ]);
    expect(harness.engines.single.loadedAssets, isEmpty);

    await _disposeTree(tester);
  });

  testWidgets('finishing a remote chapter returns to the library', (
    tester,
  ) async {
    final server = _ContentServer();
    final sharedPreferences = await _prefsWith();
    final harness = _Harness(server);
    await tester.pumpWidget(
      await _buildApp(
        sharedPreferences: sharedPreferences,
        repository: _repository(server, sharedPreferences),
        harness: harness,
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);
    await tester.tap(_remoteCta('Lire le chapitre 1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Terminer le chapitre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer le chapitre'));
    await tester.pumpAndSettle();

    expect(find.text('Chapitre terminé'), findsOneWidget);
    expect(find.text('Vous avez terminé ce livre !'), findsOneWidget);
    expect(find.text('Retour à la bibliothèque'), findsOneWidget);
    expect(
      sharedPreferences.getBool(
        PrefsKeys.readingCompleted('night-train', 'chapter-01'),
      ),
      isTrue,
    );
    expect(sharedPreferences.getString(PrefsKeys.programSessions), isNull);

    await tester.ensureVisible(find.text('Retour à la bibliothèque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retour à la bibliothèque'));
    await tester.pumpAndSettle();

    expect(find.text('Choisissez une histoire'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('an offline start falls back to the embedded pilot', (
    tester,
  ) async {
    final server = _ContentServer()..offline = true;
    final sharedPreferences = await _prefsWith();
    final harness = _Harness(server);
    await tester.pumpWidget(
      await _buildApp(
        sharedPreferences: sharedPreferences,
        repository: _repository(server, sharedPreferences),
        harness: harness,
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    expect(
      find.text('Catalogue indisponible — dernière version enregistrée.'),
      findsOneWidget,
    );
    expect(find.text('La Légende de Sleepy Hollow'), findsOneWidget);
    expect(find.text('Le Train de Nuit'), findsNothing);
  });

  testWidgets('a cached catalogue is shown when the network is down', (
    tester,
  ) async {
    final server = _ContentServer();
    final cachedPayload = jsonEncode({
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'etag': null,
      'payload': _catalogueJson(),
    });
    final sharedPreferences = await _prefsWith({
      '${CatalogueRepository.cachePrefix}catalogue.v1': cachedPayload,
    });
    final harness = _Harness(server, offline: true);
    await tester.pumpWidget(
      await _buildApp(
        sharedPreferences: sharedPreferences,
        repository: _repository(server, sharedPreferences),
        harness: harness,
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    expect(
      find.text(
        'Catalogue en cache — actualisation automatique toutes les 12 h.',
      ),
      findsOneWidget,
    );
    expect(find.text('Le Train de Nuit'), findsOneWidget);
    expect(find.text('La Légende de Sleepy Hollow'), findsOneWidget);
    expect(find.text('Lire ce livre'), findsOneWidget);
  });

  testWidgets('the catalogue library fits a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final server = _ContentServer();
    final sharedPreferences = await _prefsWith();
    final harness = _Harness(server);
    await tester.pumpWidget(
      await _buildApp(
        sharedPreferences: sharedPreferences,
        repository: _repository(server, sharedPreferences),
        harness: harness,
      ),
    );
    await tester.pumpAndSettle();
    await _openLibrary(tester);

    await tester.scrollUntilVisible(
      find.text('Lire le chapitre 1').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Le Train de Nuit'), findsOneWidget);
  });
}
