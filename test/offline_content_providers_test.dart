import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storylingo/features/content/data/catalogue_repository.dart';
import 'package:storylingo/features/content/data/content_repository.dart';
import 'package:storylingo/features/content/domain/catalogue.dart';
import 'package:storylingo/features/content/domain/content_offline_exception.dart';
import 'package:storylingo/features/downloads/application/download_providers.dart';
import 'package:storylingo/features/downloads/data/download_platform.dart';
import 'package:storylingo/features/downloads/data/pack_store.dart';

import 'support/in_memory_pack_store.dart';
import 'support/pack_fixtures.dart';
import 'support/pack_seed.dart';

const _baseUrl = 'http://content.test';

Map<String, dynamic> _catalogueJson() => {
  'updatedAt': '2026-11-22T10:00:00Z',
  'books': [
    {
      'id': 'quiet-road',
      'title': 'Quiet Road',
      'titleFr': 'La Route Tranquille',
      'author': 'Remote Author',
      'level': 'a2',
      'descriptionFr': 'Une route distante.',
      'packVersion': '2.0.0',
      'chapterCount': 1,
      'totalMinutes': 5,
      'newWordCount': 1,
      'isFree': true,
      'manifestUrl': '/v1/books/quiet-road',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late InMemoryPackStore store;
  late PackFixture fixture;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = InMemoryPackStore();
    fixture = PackFixture();
  });

  ProviderContainer containerWith(CatalogueRepository? repository) {
    return ProviderContainer(
      overrides: [
        downloadPlatformProvider.overrideWithValue(DownloadPlatform.mobile),
        packStoreProvider.overrideWithValue(store),
        catalogueRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  test('installed packs keep priority over a newer network manifest', () async {
    await seedPack(store, fixture);
    final remoteManifest = downloadedManifestJson(packVersion: '2.0.0');
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path == '/v1/catalogue') {
        return http.Response.bytes(
          utf8.encode(jsonEncode(_catalogueJson())),
          200,
        );
      }
      if (request.url.path == '/v1/books/quiet-road') {
        return http.Response.bytes(
          utf8.encode(jsonEncode(remoteManifest)),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final repository = CatalogueRepository(
      baseUrl: _baseUrl,
      preferences: preferences,
      client: client,
    );
    addTearDown(repository.dispose);
    final container = containerWith(repository);
    addTearDown(container.dispose);

    final view = await container.read(catalogueProvider.future);
    expect(view.source, CatalogueSource.network);
    final entry = view.books.firstWhere((book) => book.id == 'quiet-road');
    expect(entry.packVersion, '2.0.0');
    expect(entry.isEmbedded, isFalse);
    expect(
      view.books.map((book) => book.id),
      containsAll(['sleepy-hollow', 'quiet-road']),
    );

    final manifest = await container.read(
      bookManifestProvider('quiet-road').future,
    );
    expect(manifest.packVersion, '1.0.0');

    final chapter = await container.read(
      chapterProvider((bookId: 'quiet-road', chapterId: 'chapter-01')).future,
    );
    expect(chapter.title, 'A Quiet Valley');
    expect(
      chapter.audio?.localFile,
      '/memory/packs/quiet-road/audio/chapter-01.mp3',
    );
    expect(calls, isNot(contains('/v1/books/quiet-road/chapters/chapter-01')));
  });

  test('a downloaded book stays in the catalogue without a server', () async {
    await seedPack(store, fixture);
    final container = containerWith(null);
    addTearDown(container.dispose);

    final view = await container.read(catalogueProvider.future);
    expect(view.source, CatalogueSource.fallback);
    expect(view.books.map((book) => book.id), ['quiet-road', 'sleepy-hollow']);
  });

  test('an uninstalled chapter offline tells the user to download', () async {
    var offline = false;
    final client = MockClient((request) async {
      if (offline) throw http.ClientException('offline', request.url);
      if (request.url.path == '/v1/books/quiet-road') {
        return http.Response.bytes(
          utf8.encode(jsonEncode(downloadedManifestJson())),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final repository = CatalogueRepository(
      baseUrl: _baseUrl,
      preferences: preferences,
      client: client,
    );
    addTearDown(repository.dispose);
    await repository.loadManifest('quiet-road');

    offline = true;
    final container = containerWith(repository);
    addTearDown(container.dispose);

    await expectLater(
      container.read(
        chapterProvider((bookId: 'quiet-road', chapterId: 'chapter-01')).future,
      ),
      throwsA(
        isA<ContentOfflineException>().having(
          (error) => error.message,
          'message',
          contains('pas téléchargé'),
        ),
      ),
    );
  });

  test('a corrupted installed chapter fails fast with a clear message', () async {
    await seedPack(store, fixture);
    await store.writeStringAtomic(
      PackPaths.relative('quiet-road', 'chapters/chapter-01.json'),
      '{ broken',
    );
    final container = containerWith(null);
    addTearDown(container.dispose);

    await expectLater(
      container.read(
        chapterProvider((bookId: 'quiet-road', chapterId: 'chapter-01')).future,
      ),
      throwsA(
        isA<ContentOfflineException>().having(
          (error) => error.message,
          'message',
          contains('endommagé'),
        ),
      ),
    );
  });
}
