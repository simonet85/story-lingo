import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storylingo/features/content/data/local_pack_content.dart';
import 'package:storylingo/features/downloads/data/download_repository.dart';
import 'package:storylingo/features/downloads/data/pack_downloader.dart';
import 'package:storylingo/features/downloads/data/pack_store.dart';
import 'package:storylingo/features/downloads/data/pack_store_io.dart';
import 'package:storylingo/features/downloads/data/pack_store_stub.dart';
import 'package:storylingo/features/downloads/domain/download_descriptor.dart';
import 'package:storylingo/features/downloads/domain/download_exception.dart';

import 'support/pack_fixtures.dart';

const _baseUrl = 'http://content.test';

http.Client _clientFor(PackFixture fixture, {String? corruptAudioSha}) {
  final descriptor = fixture.descriptorJson(corruptAudioSha: corruptAudioSha);
  return MockClient((request) async {
    if (request.url.path == '/v1/books/${fixture.bookId}/download') {
      return http.Response.bytes(utf8.encode(jsonEncode(descriptor)), 200);
    }
    final bytes = fixture.servedFiles[request.url.path];
    if (bytes == null) return http.Response('not found', 404);
    return http.Response.bytes(bytes, 200);
  });
}

Future<Directory> _tempDir() => Directory.systemTemp.createTemp('storylingo_');

void main() {
  late Directory temp;
  late IoPackStore store;

  setUp(() async {
    temp = await _tempDir();
    store = IoPackStore(rootOverride: temp.path);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  PackDownloader downloaderFor(http.Client client) => PackDownloader(
    store: store,
    baseUrl: _baseUrl,
    client: client,
    now: () => DateTime.utc(2026, 11, 22),
  );

  test('downloads, verifies and installs a pack', () async {
    final fixture = PackFixture();
    final progress = <(int, int)>[];
    final installed = await downloaderFor(_clientFor(fixture)).download(
      bookId: fixture.bookId,
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(installed.bookId, fixture.bookId);
    expect(installed.title, 'The Legend of Sleepy Hollow');
    expect(installed.packVersion, fixture.packVersion);
    expect(installed.fileCount, 3);
    expect(
      installed.totalBytes,
      fixture.manifestBytes.length +
          fixture.chapterBytes.length +
          fixture.audioBytes.length,
    );
    expect(progress.first, (0, installed.totalBytes));
    expect(progress.last, (installed.totalBytes, installed.totalBytes));

    expect(
      await store.readBytes(
        PackPaths.relative(fixture.bookId, 'manifest.json'),
      ),
      fixture.manifestBytes,
    );
    expect(
      await store.readBytes(
        PackPaths.relative(fixture.bookId, 'audio/chapter-01.mp3'),
      ),
      fixture.audioBytes,
    );
    expect(await store.listNames(PackPaths.staging), isEmpty);
    expect(await store.listNames(PackPaths.trash), isEmpty);
  });

  test('install writes a pack.json usable by the repository', () async {
    final fixture = PackFixture();
    final installed = await downloaderFor(_clientFor(fixture))
        .download(bookId: fixture.bookId);
    final repository = DownloadRepository(store: store);
    await repository.recordInstalled(installed);

    final index = await repository.reconcile();
    expect(index[fixture.bookId]?.packVersion, fixture.packVersion);

    final stored = await repository.readPack(fixture.bookId);
    expect(stored, isNotNull);
    expect(stored!.descriptor.files, hasLength(3));
    expect(stored.descriptor.files[1].kind, DownloadFileKind.chapter);

    final audioPath = await repository.localAudioPath(
      fixture.bookId,
      fixture.audioUrl,
    );
    expect(
      audioPath,
      await store.absolutePath('packs/${fixture.bookId}/audio/chapter-01.mp3'),
    );
    expect(await File(audioPath!).readAsBytes(), fixture.audioBytes);
  });

  test(
    'local content reads chapters by descriptor and attaches audio',
    () async {
      final fixture = PackFixture();
      final installed = await downloaderFor(_clientFor(fixture))
          .download(bookId: fixture.bookId);
      final repository = DownloadRepository(store: store);
      await repository.recordInstalled(installed);

      final local = LocalPackContent(store: store, repository: repository);
      final manifest = await local.loadManifest(fixture.bookId);
      expect(manifest?.chapters.single.url, isNotNull);
      expect(manifest?.chapters.single.asset, isNull);

      final chapter = await local.loadChapter(fixture.bookId, 'chapter-01');
      expect(chapter?.id, 'chapter-01');
      expect(chapter?.audio?.url, fixture.audioUrl);
      expect(chapter?.audio?.localFile, isNotNull);
      expect(
        await File(chapter!.audio!.localFile!).readAsBytes(),
        fixture.audioBytes,
      );
    },
  );

  test('removes an installed pack and its index entry', () async {
    final fixture = PackFixture();
    final installed = await downloaderFor(_clientFor(fixture))
        .download(bookId: fixture.bookId);
    final repository = DownloadRepository(store: store);
    await repository.recordInstalled(installed);

    await repository.remove(fixture.bookId);
    final index = await repository.reconcile();
    expect(index.isEmpty, isTrue);
    expect(await store.exists(PackPaths.pack(fixture.bookId)), isFalse);
    expect(
      await repository.localAudioPath(fixture.bookId, fixture.audioUrl),
      isNull,
    );
  });

  test(
    'a corrupted file fails integrity and leaves no installed pack',
    () async {
      final fixture = PackFixture();
      final wrongHash = sha256Hex(utf8.encode('not the served audio'));
      final downloader = downloaderFor(
        _clientFor(fixture, corruptAudioSha: wrongHash),
      );

      await expectLater(
        downloader.download(bookId: fixture.bookId),
        throwsA(
          isA<DownloadIntegrityException>().having(
            (error) => error.message,
            'message',
            contains('corrompu'),
          ),
        ),
      );
      expect(await store.listNames(PackPaths.packs), isEmpty);
      expect(await store.listNames(PackPaths.staging), isEmpty);
    },
  );

  test('an already cancelled token never hits the network', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 500);
    });
    final token = DownloadCancelToken()..cancel();

    await expectLater(
      downloaderFor(client).download(bookId: 'quiet-road', cancelToken: token),
      throwsA(isA<DownloadCancelledException>()),
    );
    expect(calls, 0);
    expect(await store.listNames(PackPaths.staging), isEmpty);
  });

  test(
    'reports HTTP failures and unsupported or missing configuration',
    () async {
      final notFound = MockClient(
        (request) async => http.Response('{"detail":"not found"}', 404),
      );
      await expectLater(
        downloaderFor(notFound).download(bookId: 'quiet-road'),
        throwsA(isA<DownloadHttpException>()),
      );

      final unsupported = PackDownloader(
        store: StubPackStore(),
        baseUrl: _baseUrl,
        client: _clientFor(PackFixture()),
      );
      await expectLater(
        unsupported.download(bookId: 'quiet-road'),
        throwsA(isA<DownloadUnsupportedException>()),
      );

      final misconfigured = PackDownloader(
        store: store,
        baseUrl: '  ',
        client: _clientFor(PackFixture()),
      );
      await expectLater(
        misconfigured.download(bookId: 'quiet-road'),
        throwsA(isA<DownloadConfigException>()),
      );
    },
  );
}
