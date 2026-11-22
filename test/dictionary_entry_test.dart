import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/content/domain/chapter.dart';
import 'package:storylingo/features/content/domain/chapter_dictionary.dart';
import 'package:storylingo/features/vocabulary/domain/word_entry.dart';

import 'support/content_fixtures.dart';

Map<String, dynamic> _sleepyHollowChapterJson() => {
  'schemaVersion': 2,
  'id': 'chapter-01',
  'bookId': 'sleepy-hollow',
  'number': 1,
  'title': 'A Quiet Valley',
  'level': 'a2',
  'paragraphs': <Map<String, dynamic>>[
    {
      'id': 'p-01',
      'segments': <Map<String, dynamic>>[
        {'text': 'At '},
        {'text': 'Sleepy Hollow', 'vocabId': 'sleepy-hollow'},
        {'text': ' the mist came.'},
      ],
    },
  ],
  'vocabulary': <Map<String, dynamic>>[
    {
      'id': 'sleepy-hollow',
      'word': 'Sleepy Hollow',
      'partOfSpeech': 'proper noun',
      'phonetic': '/ˈsliːpi ˈhɒləʊ/',
      'definitionEn': 'a small, quiet valley',
      'translationFr': 'un vallon endormi',
      'example': 'Sleepy Hollow was a quiet place by the river.',
    },
  ],
  'audio': <String, dynamic>{
    'asset': 'assets/content/sleepy-hollow-a2/audio/chapter-01.mp3',
    'durationMs': 1700,
    'voice': 'en-US-AriaNeural',
    'words': <Map<String, dynamic>>[
      {'text': 'At', 'startMs': 0, 'endMs': 200},
      {'text': 'Sleepy', 'startMs': 200, 'endMs': 500},
      {'text': 'Hollow', 'startMs': 500, 'endMs': 900},
      {'text': 'the', 'startMs': 900, 'endMs': 1100},
      {'text': 'mist', 'startMs': 1100, 'endMs': 1300},
      {'text': 'came', 'startMs': 1300, 'endMs': 1600},
    ],
  },
};

ChapterWord _word(Chapter chapter, String text) {
  return chapter.layout.words.firstWhere((word) => word.text == text);
}

void main() {
  group('dictionaryEntryFor', () {
    test('returns null for a token without vocabulary annotation', () {
      final chapter = Chapter.fromJson(validAudioChapterJson());

      expect(dictionaryEntryFor(chapter, _word(chapter, 'The')), isNull);
      expect(dictionaryEntryFor(chapter, _word(chapter, 'covered')), isNull);
    });

    test('maps the vocabulary card and the token timing', () {
      final chapter = Chapter.fromJson(validAudioChapterJson());

      final entry = dictionaryEntryFor(chapter, _word(chapter, 'mist'))!;

      expect(entry.id, 'sleepy-hollow/mist');
      expect(entry.word, 'mist');
      expect(entry.partOfSpeech, 'noun');
      expect(entry.phonetic, '/mɪst/');
      expect(entry.definitionEn, 'thin fog close to the ground');
      expect(entry.translationFr, 'la brume');
      expect(entry.example, 'A cold mist covered the fields.');
      expect(entry.bookId, 'sleepy-hollow');
      expect(entry.chapterId, 'chapter-01');
      expect(entry.clip, isNotNull);
      expect(entry.clip!.asset, contains('chapter-01.mp3'));
      expect(entry.clip!.start, const Duration(milliseconds: 300));
      expect(entry.clip!.end, const Duration(milliseconds: 700));
    });

    test('covers every token of a multi-word entry with the clip', () {
      final chapter = Chapter.fromJson(_sleepyHollowChapterJson());

      final fromSleepy = dictionaryEntryFor(chapter, _word(chapter, 'Sleepy'))!;
      final fromHollow = dictionaryEntryFor(chapter, _word(chapter, 'Hollow'))!;

      expect(fromSleepy.id, 'sleepy-hollow/sleepy-hollow');
      expect(fromSleepy.word, 'Sleepy Hollow');
      expect(fromSleepy.clip!.start, const Duration(milliseconds: 200));
      expect(fromSleepy.clip!.end, const Duration(milliseconds: 900));
      expect(fromHollow.clip!.start, fromSleepy.clip!.start);
      expect(fromHollow.clip!.end, fromSleepy.clip!.end);
    });

    test('returns a card without clip when the chapter has no audio', () {
      final chapter = Chapter.fromJson(validChapterJson());

      final entry = dictionaryEntryFor(chapter, _word(chapter, 'mist'))!;

      expect(entry.translationFr, 'la brume');
      expect(entry.clip, isNull);
    });
  });

  group('partOfSpeechLabel', () {
    test('translates the pack labels', () {
      expect(partOfSpeechLabel('noun'), 'nom');
      expect(partOfSpeechLabel('proper noun'), 'nom propre');
      expect(partOfSpeechLabel('verb'), 'verbe');
      expect(partOfSpeechLabel('adjective'), 'adjectif');
      expect(partOfSpeechLabel('adverb'), 'adverbe');
    });

    test('keeps unknown labels and trims them', () {
      expect(partOfSpeechLabel(' idiom '), 'idiom');
      expect(partOfSpeechLabel(''), '');
    });
  });
}
