import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storylingo/core/config/api_config.dart';
import 'package:storylingo/features/billing/application/book_access_provider.dart';
import 'package:storylingo/features/downloads/application/download_providers.dart';
import 'package:storylingo/features/downloads/data/download_platform.dart';
import 'package:storylingo/features/downloads/data/download_repository.dart';
import 'package:storylingo/features/downloads/data/pack_downloader.dart';
import 'package:storylingo/features/downloads/data/pack_store.dart';
import 'package:storylingo/features/downloads/domain/download_exception.dart';
import 'package:storylingo/features/downloads/domain/download_descriptor.dart';
import 'package:storylingo/features/downloads/domain/installed_pack.dart';
import 'package:storylingo/features/downloads/presentation/book_download_control.dart';
import 'package:storylingo/features/downloads/presentation/downloads_section.dart';

import 'support/in_memory_pack_store.dart';
import 'support/pack_fixtures.dart';

const _baseUrl = 'http://content.test';

class _ControlledDownloader extends PackDownloader {
  _ControlledDownloader({required super.store}) : super(baseUrl: _baseUrl);

  final Completer<InstalledPack> completer = Completer<InstalledPack>();

  @override
  Future<InstalledPack> download({
    required String bookId,
    DownloadProgress? onProgress,
    DownloadCancelToken? cancelToken,
  }) {
    onProgress?.call(5, 10);
    cancelToken?.throwIfCancelled();
    return completer.future;
  }
}

class _SeededDownloader extends PackDownloader {
  _SeededDownloader({required super.store, required this.onDownload})
    : super(baseUrl: _baseUrl);

  final Future<InstalledPack> Function() onDownload;

  @override
  Future<InstalledPack> download({
    required String bookId,
    DownloadProgress? onProgress,
    DownloadCancelToken? cancelToken,
  }) => onDownload();
}

http.Client _successClient(PackFixture fixture) {
  final descriptor = fixture.descriptorJson();
  return MockClient((request) async {
    if (request.url.path == '/v1/books/${fixture.bookId}/download') {
      return http.Response.bytes(utf8.encode(jsonEncode(descriptor)), 200);
    }
    final bytes = fixture.servedFiles[request.url.path];
    if (bytes == null) return http.Response('not found', 404);
    return http.Response.bytes(bytes, 200);
  });
}

Future<InstalledPack> _seed(
  InMemoryPackStore store,
  PackFixture fixture, {
  String? packVersion,
}) async {
  final version = packVersion ?? fixture.packVersion;
  final descriptor = DownloadDescriptor.fromJson(fixture.descriptorJson());
  await store.writeBytes(
    PackPaths.relative(fixture.bookId, 'manifest.json'),
    fixture.manifestBytes,
  );
  await store.writeBytes(
    PackPaths.relative(fixture.bookId, 'chapters/chapter-01.json'),
    fixture.chapterBytes,
  );
  await store.writeBytes(
    PackPaths.relative(fixture.bookId, 'audio/chapter-01.mp3'),
    fixture.audioBytes,
  );
  final installed = InstalledPack(
    bookId: fixture.bookId,
    title: 'The Legend of Sleepy Hollow',
    packVersion: version,
    downloadedAt: DateTime.utc(2026, 11, 22),
    totalBytes: descriptor.totalBytes,
    fileCount: descriptor.files.length,
    baseUrl: _baseUrl,
  );
  await store.writeStringAtomic(
    PackPaths.descriptor(fixture.bookId),
    jsonEncode({
      'schemaVersion': 1,
      'installed': installed.toJson(),
      'descriptor': descriptor.toJson(),
    }),
  );
  await DownloadRepository(store: store).recordInstalled(installed);
  return installed;
}

Widget _controlApp(
  InMemoryPackStore store,
  http.Client client, {
  String availableVersion = '1.0.0',
  PackDownloader? downloader,
}) {
  return ProviderScope(
    overrides: [
      downloadPlatformProvider.overrideWithValue(DownloadPlatform.mobile),
      packStoreProvider.overrideWithValue(store),
      apiBaseUrlProvider.overrideWithValue(_baseUrl),
      downloadHttpClientProvider.overrideWithValue(client),
      bookAccessProvider.overrideWith((ref, bookId) => BookAccess.free),
      if (downloader != null)
        packDownloaderProvider.overrideWithValue(downloader),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BookDownloadControl(
            bookId: 'quiet-road',
            availableVersion: availableVersion,
          ),
        ),
      ),
    ),
  );
}

Widget _sectionApp(
  InMemoryPackStore store, {
  DownloadPlatform platform = DownloadPlatform.mobile,
}) {
  return ProviderScope(
    overrides: [
      downloadPlatformProvider.overrideWithValue(platform),
      packStoreProvider.overrideWithValue(store),
      apiBaseUrlProvider.overrideWithValue(_baseUrl),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: DownloadsSection(),
        ),
      ),
    ),
  );
}

void main() {
  late InMemoryPackStore store;
  late PackFixture fixture;

  setUp(() {
    store = InMemoryPackStore();
    fixture = PackFixture();
  });

  testWidgets('a card downloads a book and displays the installed state', (
    tester,
  ) async {
    final downloader = _SeededDownloader(
      store: store,
      onDownload: () => _seed(store, fixture),
    );
    await tester.pumpWidget(
      _controlApp(store, _successClient(fixture), downloader: downloader),
    );
    await tester.pumpAndSettle();

    expect(find.text('Télécharger'), findsOneWidget);
    await tester.tap(find.text('Télécharger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Téléchargé ·'), findsOneWidget);
    expect(find.text('Télécharger'), findsNothing);
    expect(await store.exists(PackPaths.pack(fixture.bookId)), isTrue);
    expect(
      jsonDecode(
        (await store.readString(PackPaths.index))!,
      )['packs'][fixture.bookId]['packVersion'],
      '1.0.0',
    );
  });

  testWidgets('a download shows progress and can be cancelled', (tester) async {
    final downloader = _ControlledDownloader(store: store);
    await tester.pumpWidget(
      _controlApp(store, _successClient(fixture), downloader: downloader),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Télécharger'));
    await tester.pump();
    expect(find.text('Téléchargement… 50 %'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(find.text('Annulation…'), findsOneWidget);

    downloader.completer.completeError(const DownloadCancelledException());
    await tester.pumpAndSettle();
    expect(find.text('Téléchargement annulé.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('a failed download shows the server message and retry', (
    tester,
  ) async {
    final failing = MockClient(
      (request) async => http.Response('{"detail":"boom"}', 500),
    );
    await tester.pumpWidget(_controlApp(store, failing));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Télécharger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Le serveur a répondu 500'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(await store.exists(PackPaths.pack(fixture.bookId)), isFalse);
  });

  testWidgets('an installed pack with a newer version advertises the update', (
    tester,
  ) async {
    await _seed(store, fixture);
    await tester.pumpWidget(
      _controlApp(store, _successClient(fixture), availableVersion: '2.0.0'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Téléchargé ·'), findsOneWidget);
    expect(find.text('Mise à jour'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget);
  });

  testWidgets('settings lists downloaded packs and deletes them', (
    tester,
  ) async {
    await _seed(store, fixture);
    await tester.pumpWidget(_sectionApp(store));
    await tester.pumpAndSettle();

    expect(find.text('Téléchargements'), findsOneWidget);
    expect(find.text('The Legend of Sleepy Hollow'), findsOneWidget);
    expect(find.textContaining('Version 1.0.0'), findsOneWidget);
    expect(find.textContaining('utilisés sur cet appareil'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer The Legend of Sleepy Hollow'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Le livre restera disponible en streaming.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucun livre téléchargé.'), findsOneWidget);
    expect(await store.exists(PackPaths.pack(fixture.bookId)), isFalse);
  });

  testWidgets('the web build explains that downloads are mobile-only', (
    tester,
  ) async {
    await tester.pumpWidget(_sectionApp(store, platform: DownloadPlatform.web));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('disponible sur l’application mobile'),
      findsOneWidget,
    );
    expect(find.text('Aucun livre téléchargé.'), findsNothing);
  });

  testWidgets('the downloads section fits a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _seed(store, fixture);
    await tester.pumpWidget(_sectionApp(store));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('The Legend of Sleepy Hollow'), findsOneWidget);
  });
}
