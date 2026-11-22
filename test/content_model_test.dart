import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/content/domain/book_manifest.dart';
import 'package:storylingo/features/content/domain/chapter.dart';
import 'package:storylingo/features/content/domain/content_format_exception.dart';

import 'support/content_fixtures.dart';

Matcher throwsContentFormat() => throwsA(isA<ContentFormatException>());

void main() {
  group('BookManifest', () {
    test('accepts a valid manifest', () {
      final manifest = BookManifest.fromJson(validManifestJson());

      expect(manifest.schemaVersion, 1);
      expect(manifest.packVersion, '1.0.0');
      expect(manifest.id, 'sleepy-hollow');
      expect(manifest.title, 'The Legend of Sleepy Hollow');
      expect(manifest.author, 'Washington Irving');
      expect(manifest.level.shortLabel, 'A2');
      expect(manifest.chapters, hasLength(1));
      expect(manifest.chapters.first.estimatedMinutes, 6);
      expect(manifest.totalEstimatedMinutes, 6);
      expect(manifest.totalNewWords, 1);
    });

    test('rejects an unknown schema version', () {
      final json = validManifestJson()..['schemaVersion'] = 2;

      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });

    test('rejects a non-semver pack version', () {
      final json = validManifestJson()..['packVersion'] = '1.0';

      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });

    test('rejects an invalid CEFR level', () {
      final json = validManifestJson()..['level'] = 'c1';

      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });

    test('rejects estimated minutes outside 1-30', () {
      final json = validManifestJson();
      final chapters = json['chapters'] as List<dynamic>;
      final chapter = chapters.first as Map<String, dynamic>;

      chapter['estimatedMinutes'] = 0;
      expect(() => BookManifest.fromJson(json), throwsContentFormat());

      chapter['estimatedMinutes'] = 31;
      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });

    test('rejects duplicate chapter ids', () {
      final json = validManifestJson();
      final chapters = json['chapters'] as List<dynamic>;
      chapters.add(
        Map<String, dynamic>.from(chapters.first as Map<String, dynamic>)
          ..['number'] = 2,
      );

      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });

    test('rejects duplicate chapter numbers', () {
      final json = validManifestJson();
      final chapters = json['chapters'] as List<dynamic>;
      chapters.add(
        Map<String, dynamic>.from(chapters.first as Map<String, dynamic>)
          ..['id'] = 'chapter-02',
      );

      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });

    test('rejects chapter numbers with gaps', () {
      final json = validManifestJson();
      final chapter =
          (json['chapters'] as List<dynamic>).first as Map<String, dynamic>;
      chapter['number'] = 2;

      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });

    test('rejects malformed JSON input', () {
      expect(
        () => BookManifest.fromJson('{"schemaVersion": 1}'),
        throwsContentFormat(),
      );
      expect(
        () => BookManifest.fromJson({'schemaVersion': 1}),
        throwsContentFormat(),
      );
    });

    test('rejects an empty chapter list', () {
      final json = validManifestJson()..['chapters'] = <dynamic>[];

      expect(() => BookManifest.fromJson(json), throwsContentFormat());
    });
  });

  group('Chapter', () {
    test('accepts a valid chapter and computes its word count', () {
      final chapter = Chapter.fromJson(validChapterJson());

      expect(chapter.id, 'chapter-01');
      expect(chapter.bookId, 'sleepy-hollow');
      expect(chapter.level.shortLabel, 'A2');
      expect(chapter.paragraphs, hasLength(1));
      expect(chapter.paragraphs.first.text, 'The mist covered the fields.');
      expect(chapter.vocabulary, hasLength(1));
      expect(chapter.wordCount, 5);
      expect(chapter.vocabularyById('mist')?.word, 'mist');
    });

    test('rejects an unknown schema version', () {
      final json = validChapterJson()..['schemaVersion'] = 3;

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects an empty segment text', () {
      final json = validChapterJson();
      final segments = segmentsOf(firstParagraph(json));
      (segments.first as Map<String, dynamic>)['text'] = '';

      expect(() => Chapter.fromJson(json), throwsContentFormat());

      final blankJson = validChapterJson();
      final blankSegments = segmentsOf(firstParagraph(blankJson));
      (blankSegments.first as Map<String, dynamic>)['text'] = '   ';

      expect(() => Chapter.fromJson(blankJson), throwsContentFormat());
    });

    test('rejects an empty paragraph list', () {
      final json = validChapterJson()..['paragraphs'] = <dynamic>[];

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects a paragraph without segments', () {
      final json = validChapterJson();
      firstParagraph(json)['segments'] = <dynamic>[];

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects an unknown vocabId', () {
      final json = validChapterJson();
      final segments = segmentsOf(firstParagraph(json));
      (segments[1] as Map<String, dynamic>)['vocabId'] = 'unknown';

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects a duplicate vocabulary id', () {
      final json = validChapterJson();
      (json['vocabulary'] as List<dynamic>).add(validVocabularyJson());

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects vocabulary that is never used in the text', () {
      final json = validChapterJson();
      (json['vocabulary'] as List<dynamic>).add(
        validVocabularyJson()
          ..['id'] = 'hum'
          ..['word'] = 'hum',
      );

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects a vocabulary entry with a missing field', () {
      final json = validChapterJson();
      firstVocabulary(json)['phonetic'] = '';

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });
  });

  group('Chapter audio (schema v2)', () {
    test('accepts aligned timings and exposes the audio track', () {
      final chapter = Chapter.fromJson(validAudioChapterJson());

      expect(chapter.schemaVersion, 2);
      expect(chapter.hasAudio, isTrue);
      expect(chapter.audio!.durationMs, 3000);
      expect(chapter.audio!.voice, 'en-US-AriaNeural');
      expect(chapter.audio!.words, hasLength(5));
      expect(chapter.audio!.words.first.start, Duration.zero);
      expect(chapter.audio!.words.last.end, const Duration(milliseconds: 2000));
      expect(chapter.layout.words[1].text, 'mist');
      expect(chapter.layout.words[1].vocabId, 'mist');
      expect(chapter.layout.words.last.endsSentence, isTrue);
    });

    test('rejects a v2 chapter without audio', () {
      final json = validChapterJson()..['schemaVersion'] = 2;

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects a timing count that does not match the text', () {
      final json = validAudioChapterJson();
      audioWordsOf(json).removeLast();

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects a timing that does not match the token', () {
      final json = validAudioChapterJson();
      (audioWordsOf(json)[1] as Map<String, dynamic>)['text'] = 'fog';

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects timings that are not strictly increasing', () {
      final json = validAudioChapterJson();
      (audioWordsOf(json)[1] as Map<String, dynamic>)['startMs'] = 0;

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects overlapping timings', () {
      final json = validAudioChapterJson();
      (audioWordsOf(json)[1] as Map<String, dynamic>)['endMs'] = 900;

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects a duration shorter than the last word', () {
      final json = validAudioChapterJson(durationMs: 1500);

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });

    test('rejects an empty audio word list', () {
      final json = validAudioChapterJson();
      audioOf(json)['words'] = <dynamic>[];

      expect(() => Chapter.fromJson(json), throwsContentFormat());
    });
  });

  group('Chapter layout', () {
    test('reconstructs the paragraph text from its pieces', () {
      final chapter = Chapter.fromJson(validAudioChapterJson());
      final layout = chapter.layout.paragraphs.single;

      final text = layout.pieces.map((piece) => piece.text).join();
      expect(text, chapter.paragraphs.single.text);
      expect(layout.startWordIndex, 0);
      expect(layout.words.map((word) => word.text), [
        'The',
        'mist',
        'covered',
        'the',
        'fields',
      ]);
      expect(layout.words.map((word) => word.index), [0, 1, 2, 3, 4]);
      expect(layout.words.map((word) => word.endsSentence), [
        false,
        false,
        false,
        false,
        true,
      ]);
    });

    test('keeps the vocabulary style on annotated gaps', () {
      final layout = ChapterLayout.fromParagraphs(const [
        ChapterParagraph(
          id: 'p-01',
          segments: [
            TextSegment(text: 'In '),
            TextSegment(text: 'Sleepy Hollow', vocabId: 'sleepy-hollow'),
            TextSegment(text: ' woods.'),
          ],
        ),
      ]);

      final annotated = layout.words
          .where((word) => word.vocabId == 'sleepy-hollow')
          .map((word) => word.text);
      expect(annotated, ['Sleepy', 'Hollow']);

      final gap = layout.paragraphs.single.pieces.firstWhere(
        (piece) => piece.text == ' ' && piece.vocabId != null,
      );
      expect(gap.isWord, isFalse);
      expect(gap.vocabId, 'sleepy-hollow');
    });

    test('assigns sentence boundaries across paragraphs', () {
      final layout = ChapterLayout.fromParagraphs(const [
        ChapterParagraph(
          id: 'p-01',
          segments: [TextSegment(text: 'The mist fell. The fields slept.')],
        ),
        ChapterParagraph(
          id: 'p-02',
          segments: [TextSegment(text: 'Quiet.')],
        ),
      ]);

      expect(layout.words, hasLength(7));
      expect(layout.words[2].endsSentence, isTrue);
      expect(layout.words[5].endsSentence, isTrue);
      expect(layout.words[6].endsSentence, isTrue);
      expect(layout.paragraphs[1].startWordIndex, 6);
    });

    test('rejects a token that crosses a segment boundary', () {
      const paragraphs = [
        ChapterParagraph(
          id: 'p-01',
          segments: [
            TextSegment(text: 'Slee'),
            TextSegment(text: 'py.'),
          ],
        ),
      ];

      expect(
        () => ChapterLayout.fromParagraphs(paragraphs),
        throwsContentFormat(),
      );
    });
  });

  group('normalizeWord', () {
    test('lowercases and strips punctuation', () {
      expect(normalizeWord('Mist'), 'mist');
      expect(normalizeWord('“Hello,”'), 'hello');
      expect(normalizeWord('farmers’'), 'farmers');
      expect(normalizeWord("don't"), "don't");
      expect(normalizeWord('—'), '');
    });
  });
}
