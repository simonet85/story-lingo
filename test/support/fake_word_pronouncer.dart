import 'package:storylingo/features/vocabulary/domain/word_entry.dart';
import 'package:storylingo/features/vocabulary/domain/word_pronouncer.dart';

typedef PronouncedWord = ({String word, PronunciationClip? clip});

class FakeWordPronouncer implements WordPronouncer {
  final List<PronouncedWord> calls = [];
  int stopCalls = 0;
  bool failAll = false;

  @override
  Future<void> pronounce({
    required String word,
    PronunciationClip? clip,
  }) async {
    calls.add((word: word, clip: clip));
    if (failAll) throw const PronunciationException();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}
