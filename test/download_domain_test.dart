import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/downloads/domain/download_descriptor.dart';
import 'package:storylingo/features/downloads/domain/installed_pack.dart';

import 'support/pack_fixtures.dart';

Matcher throwsFormat() => throwsA(isA<FormatException>());

void main() {
  group('DownloadDescriptor', () {
    test('parses and serializes a valid descriptor', () {
      final fixture = PackFixture();
      final descriptor = DownloadDescriptor.fromJson(fixture.descriptorJson());

      expect(descriptor.bookId, 'quiet-road');
      expect(descriptor.packVersion, '1.0.0');
      expect(descriptor.files, hasLength(3));
      expect(descriptor.manifest.kind, DownloadFileKind.manifest);
      expect(descriptor.files[1].chapterId, 'chapter-01');
      expect(
        descriptor.totalBytes,
        fixture.manifestBytes.length +
            fixture.chapterBytes.length +
            fixture.audioBytes.length,
      );
      expect(
        DownloadDescriptor.fromJson(descriptor.toJson()).toJson(),
        descriptor.toJson(),
      );
    });

    test('rejects an unsupported schema version', () {
      final json = PackFixture().descriptorJson()..['schemaVersion'] = 2;
      expect(() => DownloadDescriptor.fromJson(json), throwsFormat());
    });

    test('rejects unsafe, duplicated and incomplete files', () {
      final unsafe = PackFixture().descriptorJson();
      (unsafe['files'] as List).first['path'] = '../manifest.json';
      expect(() => DownloadDescriptor.fromJson(unsafe), throwsFormat());

      final duplicated = PackFixture().descriptorJson();
      (duplicated['files'] as List).last['path'] = 'manifest.json';
      expect(() => DownloadDescriptor.fromJson(duplicated), throwsFormat());

      final noManifest = PackFixture().descriptorJson();
      (noManifest['files'] as List).removeAt(0);
      expect(() => DownloadDescriptor.fromJson(noManifest), throwsFormat());

      final noChapterId = PackFixture().descriptorJson();
      ((noChapterId['files'] as List)[1] as Map).remove('chapterId');
      expect(() => DownloadDescriptor.fromJson(noChapterId), throwsFormat());
    });

    test('rejects invalid hashes, sizes and totals', () {
      final badHash = PackFixture().descriptorJson();
      (badHash['files'] as List).first['sha256'] = 'ABC';
      expect(() => DownloadDescriptor.fromJson(badHash), throwsFormat());

      final badSize = PackFixture().descriptorJson();
      (badSize['files'] as List).first['sizeBytes'] = -1;
      expect(() => DownloadDescriptor.fromJson(badSize), throwsFormat());

      final badTotal = PackFixture().descriptorJson()..['totalBytes'] = 12;
      expect(() => DownloadDescriptor.fromJson(badTotal), throwsFormat());
    });
  });

  group('InstalledPack and DownloadIndex', () {
    InstalledPack pack(String version) => InstalledPack(
      bookId: 'quiet-road',
      title: 'Quiet Road',
      packVersion: version,
      downloadedAt: DateTime.utc(2026, 11, 22),
      totalBytes: 1200,
      fileCount: 3,
      baseUrl: 'http://content.test',
    );

    test('compares semver versions numerically', () {
      expect(pack('1.2.9').hasUpdate('1.2.10'), isTrue);
      expect(pack('1.2.10').hasUpdate('1.2.10'), isFalse);
      expect(pack('2.0.0').hasUpdate('1.9.9'), isFalse);
    });

    test('index keeps valid entries and computes totals', () {
      final index = DownloadIndex.fromJson({
        'schemaVersion': 1,
        'packs': {
          'quiet-road': pack('1.0.0').toJson(),
          'broken': {'bookId': 'broken'},
        },
      });

      expect(index.packs.keys, ['quiet-road']);
      expect(index.totalBytes, 1200);
      expect(index['quiet-road']?.title, 'Quiet Road');
      expect(index.withPack(pack('1.1.0'))['quiet-road']?.packVersion, '1.1.0');
      expect(index.without('quiet-road').isEmpty, isTrue);
    });

    test('formats bytes in French units', () {
      expect(formatBytes(12), '12 o');
      expect(formatBytes(1500), '1.5 ko');
      expect(formatBytes(2541123), '2.5 Mo');
      expect(formatBytes(2540000000), '2.5 Go');
    });

    test('maps unknown download errors to a network message', () {
      expect(
        downloadErrorMessage(StateError('boom')),
        'Téléchargement impossible. Vérifiez votre connexion.',
      );
    });
  });
}
