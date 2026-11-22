import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/features/content/data/catalogue_repository.dart';
import 'package:storylingo/features/content/domain/book_manifest.dart';
import 'package:storylingo/features/content/domain/content_format_exception.dart';

const String _baseUrl = 'http://content.test';

http.Response _jsonResponse(
  Object? payload, {
  int status = 200,
  Map<String, String> headers = const {},
}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(payload)),
    status,
    headers: headers,
  );
}

Map<String, dynamic> _catalogueJson({String packVersion = '2.0.0'}) => {
  'updatedAt': '2026-11-22T10:00:00Z',
  'books': <Map<String, dynamic>>[
    {
      'id': 'night-train',
      'title': 'The Night Train',
      'titleFr': 'Le Train de Nuit',
      'author': 'Ada Marchand',
      'level': 'b1',
      'descriptionFr': 'Un voyage qui ne devait jamais finir.',
      'packVersion': packVersion,
      'chapterCount': 1,
      'totalMinutes': 5,
      'newWordCount': 1,
      'isFree': true,
      'manifestUrl': '/v1/books/night-train',
    },
  ],
};

Map<String, dynamic> _manifestJson() => {
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

Map<String, dynamic> _chapterJson() => {
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

class _FakeServer {
  static const String etag = '"catalogue-v2"';

  final List<http.Request> requests = [];
  bool offline = false;
  bool invalidCatalogue = false;
  bool honourEtag = true;
  bool hang = false;
  Duration now = const Duration(seconds: 1);
  String cataloguePackVersion = '2.0.0';

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    if (hang) {
      return Completer<http.Response>().future;
    }
    if (offline) {
      throw http.ClientException('offline', request.url);
    }
    switch (request.url.path) {
      case '/v1/catalogue':
        if (honourEtag &&
            request.headers['If-None-Match'] == etag &&
            !invalidCatalogue) {
          return http.Response('', 304, headers: {'etag': etag});
        }
        if (invalidCatalogue) {
          return http.Response('{"books": "oops"}', 200);
        }
        return _jsonResponse(
          _catalogueJson(packVersion: cataloguePackVersion),
          headers: {'etag': etag},
        );
      case '/v1/books/night-train':
        return _jsonResponse(_manifestJson());
      case '/v1/books/night-train/chapters/chapter-01':
        return _jsonResponse(_chapterJson());
    }
    return http.Response('{"detail": "not found"}', 404);
  });

  int requestsTo(String path) =>
      requests.where((request) => request.url.path == path).length;
}

class _Harness {
  _Harness(this.server, {Duration timeout = const Duration(seconds: 3)})
    : repository = CatalogueRepository(
        baseUrl: _baseUrl,
        preferences: _prefs,
        client: server.client,
        now: () => _epoch.add(server.now),
        timeout: timeout,
      );

  static final DateTime _epoch = DateTime.utc(2026, 11, 22, 10);

  final _FakeServer server;
  final CatalogueRepository repository;
  static late SharedPreferences _prefs;

  static Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  }
}

void main() {
  setUp(_Harness.setUp);

  test('loads the remote catalogue and caches its raw payload', () async {
    final server = _FakeServer();
    final harness = _Harness(server);

    final result = await harness.repository.loadCatalogue();

    expect(result.fromCache, isFalse);
    expect(result.stale, isFalse);
    expect(result.catalogue.books.single.id, 'night-train');
    expect(result.catalogue.updatedAt, DateTime.utc(2026, 11, 22, 10));

    final raw = _Harness._prefs.getString(
      '${CatalogueRepository.cachePrefix}catalogue.v1',
    );
    final envelope = jsonDecode(raw!) as Map<String, dynamic>;
    expect(envelope['etag'], _FakeServer.etag);
    expect(
      (envelope['payload'] as Map<String, dynamic>)['updatedAt'],
      '2026-11-22T10:00:00Z',
    );

    final cached = await harness.repository.loadCatalogue();
    expect(cached.fromCache, isTrue);
    expect(cached.stale, isFalse);
    expect(server.requestsTo('/v1/catalogue'), 1);
  });

  test('revalidates with If-None-Match after the TTL', () async {
    final server = _FakeServer();
    final harness = _Harness(server);
    await harness.repository.loadCatalogue();

    server.now = const Duration(hours: 13);
    final result = await harness.repository.loadCatalogue();

    expect(result.fromCache, isTrue);
    expect(result.stale, isFalse);
    expect(server.requestsTo('/v1/catalogue'), 2);
    expect(
      server.requests.last.headers['If-None-Match'],
      _FakeServer.etag,
    );
  });

  test('falls back to the stale cache when the network fails', () async {
    final server = _FakeServer();
    final harness = _Harness(server);
    await harness.repository.loadCatalogue();

    server.now = const Duration(hours: 13);
    server.offline = true;
    final result = await harness.repository.loadCatalogue();

    expect(result.fromCache, isTrue);
    expect(result.stale, isTrue);
    expect(result.catalogue.books.single.titleFr, 'Le Train de Nuit');
  });

  test('throws a CatalogueException when offline without a cache', () async {
    final server = _FakeServer()..offline = true;
    final harness = _Harness(server);

    await expectLater(
      harness.repository.loadCatalogue(),
      throwsA(
        isA<CatalogueException>().having(
          (error) => error.message,
          'message',
          contains('unavailable'),
        ),
      ),
    );
  });

  test('times out a slow catalogue request', () async {
    final server = _FakeServer()..hang = true;
    final harness = _Harness(
      server,
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      harness.repository.loadCatalogue(),
      throwsA(isA<CatalogueException>()),
    );
  });

  test('an invalid response never overwrites a valid cache', () async {
    final server = _FakeServer();
    final harness = _Harness(server);
    await harness.repository.loadCatalogue();

    server.invalidCatalogue = true;
    server.now = const Duration(hours: 13);
    final result = await harness.repository.loadCatalogue();

    expect(result.fromCache, isTrue);
    expect(result.stale, isTrue);
    expect(result.catalogue.books.single.packVersion, '2.0.0');

    final raw = _Harness._prefs.getString(
      '${CatalogueRepository.cachePrefix}catalogue.v1',
    );
    final envelope = jsonDecode(raw!) as Map<String, dynamic>;
    final books =
        (envelope['payload'] as Map<String, dynamic>)['books'] as List<dynamic>;
    expect((books.single as Map<String, dynamic>)['packVersion'], '2.0.0');
  });

  test('caches remote manifests and serves them during an outage', () async {
    final server = _FakeServer();
    final harness = _Harness(server);

    final manifest = await harness.repository.loadManifest('night-train');
    expect(manifest.id, 'night-train');
    expect(manifest.chapters.single.isRemote, isTrue);
    expect(server.requestsTo('/v1/books/night-train'), 1);

    server.now = const Duration(hours: 13);
    server.offline = true;
    final cached = await harness.repository.loadManifest('night-train');
    expect(cached.title, 'The Night Train');
  });

  test('resolves relative audio urls and caches the remote chapter', () async {
    final server = _FakeServer();
    final harness = _Harness(server);
    final manifest = await harness.repository.loadManifest('night-train');
    final summary = manifest.chapters.single;

    final chapter = await harness.repository.loadChapter(
      bookId: 'night-train',
      summary: summary,
    );
    expect(chapter.title, 'Le Départ');
    expect(
      chapter.audio!.url,
      'http://content.test/v1/books/night-train/audio/chapter-01.mp3',
    );

    server.now = const Duration(hours: 13);
    server.offline = true;
    final cached = await harness.repository.loadChapter(
      bookId: 'night-train',
      summary: summary,
    );
    expect(cached.audio!.url, chapter.audio!.url);
  });

  test('an offline uncached chapter throws a CatalogueException', () async {
    final server = _FakeServer();
    final harness = _Harness(server);
    final manifest = await harness.repository.loadManifest('night-train');
    final summary = manifest.chapters.single;
    expect(server.requestsTo('/v1/books/night-train'), 1);

    server.now = const Duration(hours: 13);
    server.offline = true;

    await expectLater(
      harness.repository.loadChapter(bookId: 'night-train', summary: summary),
      throwsA(
        isA<CatalogueException>().having(
          (error) => error.message,
          'message',
          contains('Network error'),
        ),
      ),
    );
  });

  test('rejects a chapter that does not match the manifest entry', () async {
    final server = _FakeServer();
    final harness = _Harness(server);
    final summary = BookChapterSummary(
      id: 'chapter-02',
      number: 2,
      title: 'Le Départ',
      url: '/v1/books/night-train/chapters/chapter-01',
      estimatedMinutes: 5,
      newWordCount: 1,
    );

    await expectLater(
      harness.repository.loadChapter(bookId: 'night-train', summary: summary),
      throwsA(isA<ContentFormatException>()),
    );
  });

  test('rejects a manifest published under the wrong id', () async {
    final payload = _manifestJson()..['id'] = 'other-book';
    final client = MockClient((_) async => _jsonResponse(payload));
    final repository = CatalogueRepository(
      baseUrl: _baseUrl,
      preferences: _Harness._prefs,
      client: client,
    );

    await expectLater(
      repository.loadManifest('night-train'),
      throwsA(isA<ContentFormatException>()),
    );
  });
}
