import 'dart:convert';

import 'package:storylingo/features/downloads/data/download_repository.dart';
import 'package:storylingo/features/downloads/data/pack_store.dart';
import 'package:storylingo/features/downloads/domain/download_descriptor.dart';
import 'package:storylingo/features/downloads/domain/installed_pack.dart';

import 'in_memory_pack_store.dart';
import 'pack_fixtures.dart';

Future<InstalledPack> seedPack(
  InMemoryPackStore store,
  PackFixture fixture, {
  String? packVersion,
  String baseUrl = 'http://content.test',
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
    baseUrl: baseUrl,
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
