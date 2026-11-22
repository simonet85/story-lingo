import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/billing/application/book_access_provider.dart';
import 'package:storylingo/features/billing/application/entitlement_provider.dart';
import 'package:storylingo/features/content/data/content_repository.dart';
import 'package:storylingo/features/content/domain/book_manifest.dart';
import 'package:storylingo/features/content/domain/catalogue.dart';
import 'package:storylingo/features/downloads/application/download_providers.dart';
import 'package:storylingo/features/downloads/domain/installed_pack.dart';
import 'package:storylingo/features/onboarding/domain/user_level.dart';

void main() {
  BookManifest manifest(String id, {required bool isFree}) => BookManifest(
    schemaVersion: 1,
    packVersion: '1.0.0',
    id: id,
    title: id,
    titleFr: id,
    author: 'Storylingo',
    level: UserLevel.a2,
    descriptionFr: 'Description.',
    chapters: const [
      BookChapterSummary(
        id: 'chapter-01',
        number: 1,
        title: 'Chapitre',
        asset: 'chapters/chapter-01.json',
        estimatedMinutes: 1,
        newWordCount: 0,
      ),
    ],
    isFree: isFree,
  );

  final installed = InstalledPack(
    bookId: 'paid-book',
    title: 'Paid',
    packVersion: '1.0.0',
    downloadedAt: DateTime.utc(2026, 1, 1),
    totalBytes: 10,
    fileCount: 1,
    baseUrl: '',
  );

  CatalogueView view({required bool isFree}) {
    final book = manifest('paid-book', isFree: isFree);
    final pilot = manifest('sleepy-hollow', isFree: true);
    return CatalogueView(
      pilot: pilot,
      books: [
        CatalogueBook.fromManifest(book, isEmbedded: false),
        CatalogueBook.fromManifest(pilot),
      ],
      source: CatalogueSource.network,
    );
  }

  ProviderContainer buildContainer({
    required bool installedPack,
    required bool entitled,
    CatalogueView? catalogue,
    Future<CatalogueView>? pendingCatalogue,
  }) {
    return ProviderContainer(
      overrides: [
        installedPackProvider.overrideWith(
          (ref, bookId) => installedPack ? installed : null,
        ),
        isEntitledProvider.overrideWithValue(entitled),
        if (pendingCatalogue != null)
          catalogueProvider.overrideWith((ref) => pendingCatalogue)
        else
          catalogueProvider.overrideWith((ref) async => catalogue!),
      ],
    );
  }

  test('an installed pack wins over the subscription', () {
    final container = buildContainer(
      installedPack: true,
      entitled: true,
      catalogue: view(isFree: false),
    );
    addTearDown(container.dispose);
    expect(container.read(bookAccessProvider('paid-book')), BookAccess.installed);
  });

  test('an installed paid pack stays readable without a subscription', () {
    final container = buildContainer(
      installedPack: true,
      entitled: false,
      catalogue: view(isFree: false),
    );
    addTearDown(container.dispose);
    expect(container.read(bookAccessProvider('paid-book')), BookAccess.installed);
  });

  test('a subscription unlocks a paid catalogue book', () {
    final container = buildContainer(
      installedPack: false,
      entitled: true,
      catalogue: view(isFree: false),
    );
    addTearDown(container.dispose);
    expect(
      container.read(bookAccessProvider('paid-book')),
      BookAccess.subscribed,
    );
  });

  test('a free catalogue book needs no subscription', () async {
    final container = buildContainer(
      installedPack: false,
      entitled: false,
      catalogue: view(isFree: true),
    );
    addTearDown(container.dispose);
    await container.read(catalogueProvider.future);
    expect(container.read(bookAccessProvider('paid-book')), BookAccess.free);
  });

  test('a paid catalogue book is locked without a subscription', () async {
    final container = buildContainer(
      installedPack: false,
      entitled: false,
      catalogue: view(isFree: false),
    );
    addTearDown(container.dispose);
    await container.read(catalogueProvider.future);
    expect(container.read(bookAccessProvider('paid-book')), BookAccess.locked);
  });

  test('access stays unknown while the catalogue loads', () {
    final container = buildContainer(
      installedPack: false,
      entitled: false,
      pendingCatalogue: Completer<CatalogueView>().future,
    );
    addTearDown(container.dispose);
    expect(container.read(bookAccessProvider('paid-book')), BookAccess.unknown);
  });
}
