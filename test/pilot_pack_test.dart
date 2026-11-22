import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/content/data/content_repository.dart';
import 'package:storylingo/features/content/domain/book_manifest.dart';
import 'package:storylingo/features/content/domain/chapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookManifest manifest;
  late Map<String, Chapter> chapters;

  setUpAll(() async {
    final repository = ContentRepository();
    manifest = await repository.loadPilotManifest();
    chapters = {
      for (final summary in manifest.chapters)
        summary.id: await repository.loadChapter(
          manifest: manifest,
          chapterId: summary.id,
        ),
    };
  });

  test('manifest describes the complete pilot book', () {
    expect(manifest.schemaVersion, 1);
    expect(manifest.packVersion, '1.3.0');
    expect(manifest.id, 'sleepy-hollow');
    expect(manifest.title, 'The Legend of Sleepy Hollow');
    expect(manifest.titleFr, 'La Légende de Sleepy Hollow');
    expect(manifest.author, 'Washington Irving');
    expect(manifest.level.id, 'a2');
    expect(manifest.descriptionFr.trim(), isNotEmpty);
    expect(manifest.chapters, hasLength(3));
    expect(manifest.totalEstimatedMinutes, 18);
    expect(manifest.totalNewWords, 56);

    expect(manifest.chapters.map((chapter) => chapter.id), [
      'chapter-01',
      'chapter-02',
      'chapter-03',
    ]);
    expect(manifest.chapters.map((chapter) => chapter.title), [
      'A Quiet Valley',
      'The Midnight Rider',
      'The Morning After',
    ]);

    for (final (index, summary) in manifest.chapters.indexed) {
      expect(summary.number, index + 1);
      expect(summary.estimatedMinutes, inInclusiveRange(5, 8));
      expect(summary.newWordCount, inInclusiveRange(15, 20));
      final chapter = chapters[summary.id]!;
      expect(summary.id, chapter.id);
      expect(summary.number, chapter.number);
      expect(summary.newWordCount, chapter.vocabulary.length);
    }
  });

  test('every chapter respects the editorial constraints', () {
    for (final summary in manifest.chapters) {
      final chapter = chapters[summary.id]!;
      expect(chapter.bookId, manifest.id);
      expect(chapter.level, manifest.level);
      expect(
        chapter.paragraphs.length,
        inInclusiveRange(4, 6),
        reason: chapter.id,
      );
      expect(
        chapter.wordCount,
        inInclusiveRange(350, 450),
        reason: chapter.id,
      );

      for (final paragraph in chapter.paragraphs) {
        expect(paragraph.segments, isNotEmpty, reason: chapter.id);
        for (final segment in paragraph.segments) {
          expect(segment.text.trim(), isNotEmpty, reason: chapter.id);
        }
      }
    }
  });

  test('audio timings stay aligned with every chapter text', () {
    for (final summary in manifest.chapters) {
      final chapter = chapters[summary.id]!;
      expect(chapter.schemaVersion, 2);
      expect(chapter.hasAudio, isTrue, reason: chapter.id);

      final audio = chapter.audio!;
      expect(
        audio.asset,
        'assets/content/sleepy-hollow-a2/audio/${chapter.id}.mp3',
      );
      expect(File(audio.asset!).existsSync(), isTrue);
      expect(audio.durationMs, inInclusiveRange(120000, 150000));
      expect(audio.words, hasLength(chapter.layout.words.length));
      expect(audio.words.length, greaterThan(300));

      for (final (index, timing) in audio.words.indexed) {
        expect(timing.text, chapter.layout.words[index].text);
        expect(timing.endMs, greaterThan(timing.startMs));
      }
    }

    expect(chapters['chapter-01']!.audio!.words.length, 392);
    expect(chapters['chapter-02']!.audio!.words.length, 355);
    expect(chapters['chapter-03']!.audio!.words.length, 351);
  });

  test('vocabulary is complete, unique and fully referenced', () {
    final bookIds = <String>{};

    for (final summary in manifest.chapters) {
      final chapter = chapters[summary.id]!;
      expect(
        chapter.vocabulary.length,
        inInclusiveRange(15, 20),
        reason: chapter.id,
      );

      final ids = chapter.vocabulary.map((entry) => entry.id).toSet();
      expect(ids, hasLength(chapter.vocabulary.length));
      expect(
        bookIds.intersection(ids),
        isEmpty,
        reason: 'Duplicate vocabulary ids in ${chapter.id}',
      );
      bookIds.addAll(ids);

      final referenced = <String>{};
      for (final paragraph in chapter.paragraphs) {
        for (final segment in paragraph.segments) {
          final vocabId = segment.vocabId;
          if (vocabId == null) continue;
          expect(
            chapter.vocabularyById(vocabId),
            isNotNull,
            reason: '${chapter.id}/$vocabId',
          );
          referenced.add(vocabId);
        }
      }
      expect(referenced, ids, reason: chapter.id);

      for (final entry in chapter.vocabulary) {
        expect(entry.word.trim(), isNotEmpty);
        expect(entry.partOfSpeech.trim(), isNotEmpty);
        expect(entry.phonetic, contains('/'));
        expect(entry.definitionEn.trim(), isNotEmpty);
        expect(entry.translationFr.trim(), isNotEmpty);
        expect(entry.example.trim(), isNotEmpty);
        expect(entry.cefr, isNotNull, reason: '${chapter.id}/${entry.id}');
      }
    }

    expect(bookIds, hasLength(56));
  });
}
