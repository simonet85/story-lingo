import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/content/data/content_repository.dart';
import 'package:storylingo/features/content/domain/content_format_exception.dart';

import 'support/content_fixtures.dart';

const chapterAsset = 'assets/content/sleepy-hollow-a2/chapters/chapter-01.json';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final content = assets[key];
    if (content == null) {
      throw FlutterError('Missing asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}

ContentRepository repositoryWith({
  Map<String, dynamic>? manifest,
  Map<String, dynamic>? chapter,
}) {
  return ContentRepository(
    bundle: _FakeBundle({
      ContentRepository.pilotManifestAsset: jsonEncode(
        manifest ?? validManifestJson(),
      ),
      chapterAsset: jsonEncode(chapter ?? validChapterJson()),
    }),
  );
}

Matcher throwsContentFormat() => throwsA(isA<ContentFormatException>());

void main() {
  test('loads the manifest and a declared chapter', () async {
    final repository = repositoryWith();

    final manifest = await repository.loadPilotManifest();
    final chapter = await repository.loadChapter(
      manifest: manifest,
      chapterId: 'chapter-01',
    );

    expect(manifest.id, 'sleepy-hollow');
    expect(chapter.id, 'chapter-01');
    expect(chapter.bookId, manifest.id);
  });

  test('wraps a missing asset in a ContentFormatException', () async {
    final repository = ContentRepository(bundle: _FakeBundle(const {}));

    await expectLater(repository.loadPilotManifest(), throwsContentFormat());
  });

  test('wraps malformed JSON in a ContentFormatException', () async {
    final repository = ContentRepository(
      bundle: _FakeBundle({
        ContentRepository.pilotManifestAsset: '{ not valid json',
      }),
    );

    await expectLater(repository.loadPilotManifest(), throwsContentFormat());
  });

  test('rejects an undeclared chapter', () async {
    final repository = repositoryWith();
    final manifest = await repository.loadPilotManifest();

    await expectLater(
      repository.loadChapter(manifest: manifest, chapterId: 'chapter-42'),
      throwsContentFormat(),
    );
  });

  test('rejects a chapter whose bookId does not match the manifest', () async {
    final chapter = validChapterJson()..['bookId'] = 'other-book';
    final repository = repositoryWith(chapter: chapter);
    final manifest = await repository.loadPilotManifest();

    await expectLater(
      repository.loadChapter(manifest: manifest, chapterId: 'chapter-01'),
      throwsContentFormat(),
    );
  });

  test('rejects a chapter whose id does not match the manifest', () async {
    final chapter = validChapterJson()..['id'] = 'chapter-99';
    final repository = repositoryWith(chapter: chapter);
    final manifest = await repository.loadPilotManifest();

    await expectLater(
      repository.loadChapter(manifest: manifest, chapterId: 'chapter-01'),
      throwsContentFormat(),
    );
  });

  test('rejects a chapter whose number does not match the manifest', () async {
    final chapter = validChapterJson()..['number'] = 2;
    final repository = repositoryWith(chapter: chapter);
    final manifest = await repository.loadPilotManifest();

    await expectLater(
      repository.loadChapter(manifest: manifest, chapterId: 'chapter-01'),
      throwsContentFormat(),
    );
  });
}
