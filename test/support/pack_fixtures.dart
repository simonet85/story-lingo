import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'content_fixtures.dart';

Map<String, dynamic> downloadedManifestJson({
  String bookId = 'quiet-road',
  String packVersion = '1.0.0',
}) {
  final manifest = validManifestJson()
    ..['id'] = bookId
    ..['packVersion'] = packVersion;
  final chapter = (manifest['chapters'] as List).first as Map<String, dynamic>;
  chapter.remove('asset');
  chapter['url'] = '/v1/books/$bookId/chapters/chapter-01';
  return manifest;
}

Map<String, dynamic> downloadedChapterJson({
  String bookId = 'quiet-road',
  String chapterId = 'chapter-01',
  String audioUrl = '/v1/books/quiet-road/audio/chapter-01.mp3',
}) {
  final chapter = validAudioChapterJson()
    ..['id'] = chapterId
    ..['bookId'] = bookId;
  final audio = chapter['audio'] as Map<String, dynamic>;
  audio.remove('asset');
  audio['url'] = audioUrl;
  return chapter;
}

class PackFixture {
  PackFixture({
    this.bookId = 'quiet-road',
    this.packVersion = '1.0.0',
    String? audioContents,
  }) : manifestBytes = utf8.encode(
         jsonEncode(
           downloadedManifestJson(bookId: bookId, packVersion: packVersion),
         ),
       ),
       chapterBytes = utf8.encode(
         jsonEncode(downloadedChapterJson(bookId: bookId)),
       ),
       audioBytes = utf8.encode(audioContents ?? 'ID3 quiet road audio');

  final String bookId;
  final String packVersion;
  final List<int> manifestBytes;
  final List<int> chapterBytes;
  final List<int> audioBytes;

  String get manifestPath => '/v1/books/$bookId/files/manifest.json';
  String get chapterPath => '/v1/books/$bookId/files/chapters/chapter-01.json';
  String get audioPath => '/v1/books/$bookId/audio/chapter-01.mp3';

  Map<String, List<int>> get servedFiles => {
    manifestPath: manifestBytes,
    chapterPath: chapterBytes,
    audioPath: audioBytes,
  };

  Map<String, dynamic> descriptorJson({String? corruptAudioSha}) {
    final files = <Map<String, dynamic>>[
      _file(
        kind: 'manifest',
        path: 'manifest.json',
        url: '/v1/books/$bookId',
        downloadUrl: manifestPath,
        bytes: manifestBytes,
      ),
      _file(
        kind: 'chapter',
        path: 'chapters/chapter-01.json',
        url: '/v1/books/$bookId/chapters/chapter-01',
        downloadUrl: chapterPath,
        bytes: chapterBytes,
        chapterId: 'chapter-01',
      ),
      _file(
        kind: 'audio',
        path: 'audio/chapter-01.mp3',
        url: audioUrl,
        downloadUrl: audioPath,
        bytes: audioBytes,
        sha: corruptAudioSha,
      ),
    ];
    return {
      'schemaVersion': 1,
      'bookId': bookId,
      'packVersion': packVersion,
      'totalBytes': files.fold<int>(
        0,
        (sum, file) => sum + (file['sizeBytes'] as int),
      ),
      'files': files,
    };
  }

  String get audioUrl => '/v1/books/$bookId/audio/chapter-01.mp3';

  Map<String, dynamic> _file({
    required String kind,
    required String path,
    required String url,
    required String downloadUrl,
    required List<int> bytes,
    String? chapterId,
    String? sha,
  }) => {
    'kind': kind,
    'path': path,
    'url': url,
    'downloadUrl': downloadUrl,
    'sizeBytes': bytes.length,
    'sha256': sha ?? sha256Hex(bytes),
    'chapterId': ?chapterId,
  };
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
