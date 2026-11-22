import 'package:flutter_test/flutter_test.dart';
import 'package:storylingo/features/content/domain/chapter.dart';
import 'package:storylingo/features/reading/domain/karaoke_track.dart';

import 'support/content_fixtures.dart';

Map<String, dynamic> twoSentenceChapterJson() => {
  'schemaVersion': 2,
  'id': 'chapter-01',
  'bookId': 'sleepy-hollow',
  'number': 1,
  'title': 'Two sentences',
  'level': 'a2',
  'paragraphs': <Map<String, dynamic>>[
    {
      'id': 'p-01',
      'segments': <Map<String, dynamic>>[
        {'text': 'The mist fell.'},
      ],
    },
    {
      'id': 'p-02',
      'segments': <Map<String, dynamic>>[
        {'text': 'Fields slept.'},
      ],
    },
  ],
  'vocabulary': <dynamic>[],
  'audio': <String, dynamic>{
    'asset': 'assets/audio.mp3',
    'durationMs': 2000,
    'voice': 'voice',
    'words': <Map<String, dynamic>>[
      {'text': 'The', 'startMs': 0, 'endMs': 200},
      {'text': 'mist', 'startMs': 200, 'endMs': 500},
      {'text': 'fell', 'startMs': 500, 'endMs': 800},
      {'text': 'Fields', 'startMs': 800, 'endMs': 1100},
      {'text': 'slept', 'startMs': 1100, 'endMs': 1400},
    ],
  },
};

void main() {
  group('KaraokeTrack', () {
    late KaraokeTrack track;

    setUp(() {
      track = KaraokeTrack.fromChapter(
        Chapter.fromJson(twoSentenceChapterJson()),
      );
    });

    test('is available when timings match the chapter words', () {
      expect(track.isAvailable, isTrue);
      expect(track.timings, hasLength(5));
      expect(track.sentenceCount, 2);
    });

    test('maps positions to the spoken word', () {
      Duration at(int milliseconds) => Duration(milliseconds: milliseconds);

      expect(track.wordIndexAt(Duration.zero), 0);
      expect(track.wordIndexAt(at(199)), 0);
      expect(track.wordIndexAt(at(200)), 1);
      expect(track.wordIndexAt(at(500)), 2);
      expect(track.wordIndexAt(at(800)), 3);
      expect(track.wordIndexAt(at(1100)), 4);
      expect(track.wordIndexAt(at(5000)), 4);
    });

    test('derives sentence indices from punctuation', () {
      expect([0, 1, 2, 3, 4].map(track.sentenceIndexAtWord), [0, 0, 0, 1, 1]);
    });

    test('maps words to their paragraph', () {
      expect(track.paragraphIndexAtWord(0), 0);
      expect(track.paragraphIndexAtWord(3), 1);
      expect(track.paragraphIdAtWord(0), 'p-01');
      expect(track.paragraphIdAtWord(3), 'p-02');
      expect(track.paragraphIdAtWord(99), isNull);
      expect(track.sentenceIndexAtWord(99), isNull);
    });

    test('is unavailable without an audio track', () {
      final silent = KaraokeTrack.fromChapter(
        Chapter.fromJson(validChapterJson()),
      );

      expect(silent.isAvailable, isFalse);
      expect(silent.wordIndexAt(Duration.zero), isNull);
      expect(silent.sentenceIndexAtWord(0), 0);
    });
  });
}
