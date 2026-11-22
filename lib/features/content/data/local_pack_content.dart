import 'dart:convert';

import '../../downloads/data/download_repository.dart';
import '../../downloads/data/pack_store.dart';
import '../../downloads/domain/download_descriptor.dart';
import '../domain/book_manifest.dart';
import '../domain/chapter.dart';
import '../domain/content_format_exception.dart';

class LocalPackContent {
  LocalPackContent({required this.store, required this.repository});

  final PackStore store;
  final DownloadRepository repository;

  Future<BookManifest?> loadManifest(String bookId) async {
    final raw = await store.readString(PackPaths.manifest(bookId));
    if (raw == null) return null;
    final BookManifest manifest;
    try {
      manifest = BookManifest.fromJson(jsonDecode(raw));
    } on FormatException catch (error) {
      throw ContentFormatException(
        'Invalid downloaded manifest for "$bookId": ${error.message}',
      );
    }
    if (manifest.id != bookId) {
      throw ContentFormatException(
        'Downloaded manifest "${manifest.id}" does not match "$bookId".',
      );
    }
    return manifest;
  }

  Future<Chapter?> loadChapter(String bookId, String chapterId) async {
    final manifest = await loadManifest(bookId);
    if (manifest == null) return null;
    BookChapterSummary? summary;
    for (final chapter in manifest.chapters) {
      if (chapter.id == chapterId) {
        summary = chapter;
        break;
      }
    }
    if (summary == null) {
      throw ContentFormatException(
        'Chapter "$chapterId" is not declared in downloaded manifest '
        '"$bookId".',
      );
    }
    final pack = await repository.readPack(bookId);
    if (pack == null) return null;
    DownloadFile? stored;
    for (final file in pack.descriptor.files) {
      if (file.kind == DownloadFileKind.chapter &&
          file.chapterId == chapterId) {
        stored = file;
        break;
      }
    }
    if (stored == null) {
      throw ContentFormatException(
        'Downloaded chapter "$chapterId" is missing from the descriptor.',
      );
    }
    final raw = await store.readString(PackPaths.relative(bookId, stored.path));
    if (raw == null) {
      throw ContentFormatException(
        'Downloaded chapter file "${stored.path}" is missing.',
      );
    }
    final Chapter chapter;
    try {
      chapter = Chapter.fromJson(jsonDecode(raw));
    } on FormatException catch (error) {
      throw ContentFormatException(
        'Invalid downloaded chapter "$chapterId": ${error.message}',
      );
    }
    if (chapter.bookId != bookId ||
        chapter.id != summary.id ||
        chapter.number != summary.number) {
      throw ContentFormatException(
        'Downloaded chapter "$chapterId" does not match its manifest.',
      );
    }

    final audio = chapter.audio;
    if (audio?.url case final url?) {
      final localFile = await repository.localAudioPath(bookId, url);
      if (localFile != null) {
        return chapter.withAudio(audio!.withLocalFile(localFile));
      }
    }
    return chapter;
  }
}
